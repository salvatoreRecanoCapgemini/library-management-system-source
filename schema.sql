-- Create Tables
CREATE TABLE patrons (
    patron_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    membership_date DATE NOT NULL,
    status VARCHAR(20) CHECK (status IN ('ACTIVE', 'SUSPENDED', 'EXPIRED')),
    birth_date DATE NOT NULL
);

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    isbn VARCHAR(13) UNIQUE NOT NULL,
    title VARCHAR(200) NOT NULL,
    author VARCHAR(100) NOT NULL,
    publisher VARCHAR(100),
    publication_year INTEGER,
    category VARCHAR(50),
    total_copies INTEGER NOT NULL,
    available_copies INTEGER NOT NULL,
    location_code VARCHAR(20)
);

CREATE TABLE loans (
    loan_id SERIAL PRIMARY KEY,
    patron_id INTEGER REFERENCES patrons(patron_id),
    book_id INTEGER REFERENCES books(book_id),
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    status VARCHAR(20) CHECK (status IN ('ACTIVE', 'RETURNED', 'OVERDUE')),
    extensions_count INTEGER DEFAULT 0
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    patron_id INTEGER REFERENCES patrons(patron_id),
    book_id INTEGER REFERENCES books(book_id),
    reservation_date TIMESTAMP NOT NULL,
    expiration_date TIMESTAMP NOT NULL,
    status VARCHAR(20) CHECK (status IN ('PENDING', 'FULFILLED', 'EXPIRED')),
    notification_sent BOOLEAN DEFAULT FALSE
);
CREATE TABLE fines (
    fine_id SERIAL PRIMARY KEY,
    patron_id INTEGER REFERENCES patrons(patron_id),
    loan_id INTEGER REFERENCES loans(loan_id),
    amount DECIMAL(10,2) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    payment_date DATE,
    status VARCHAR(20) CHECK (status IN ('PENDING', 'PAID', 'WAIVED'))
);

CREATE TABLE library_events (
    event_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    event_date TIMESTAMP NOT NULL,
    duration_minutes INTEGER,
    max_participants INTEGER,
    current_participants INTEGER DEFAULT 0,
    status VARCHAR(20) CHECK (status IN ('SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED'))
);

CREATE TABLE event_registrations (
    registration_id SERIAL PRIMARY KEY,
    event_id INTEGER REFERENCES library_events(event_id),
    patron_id INTEGER REFERENCES patrons(patron_id),
    registration_date TIMESTAMP NOT NULL,
    attendance_status VARCHAR(20) CHECK (status IN ('REGISTERED', 'ATTENDED', 'NO_SHOW')),
    UNIQUE(event_id, patron_id)
);

CREATE TABLE book_reviews (
    review_id SERIAL PRIMARY KEY,
    book_id INTEGER REFERENCES books(book_id),
    patron_id INTEGER REFERENCES patrons(patron_id),
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    review_date TIMESTAMP NOT NULL,
    status VARCHAR(20) CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))
);

CREATE TABLE staff (
    staff_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    role VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    status VARCHAR(20) CHECK (status IN ('ACTIVE', 'ON_LEAVE', 'TERMINATED')),
    supervisor_id INTEGER REFERENCES staff(staff_id)
);

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER NOT NULL,
    action_type VARCHAR(20) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),
    action_timestamp TIMESTAMP NOT NULL,
    staff_id INTEGER REFERENCES staff(staff_id),
    old_values JSONB,
    new_values JSONB
);

-- Table for managing book categories with hierarchical relationships
CREATE TABLE book_categories (
    category_id SERIAL PRIMARY KEY,
    parent_category_id INTEGER REFERENCES book_categories(category_id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    depth_level INTEGER NOT NULL,
    full_path VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for managing book collections and series
CREATE TABLE book_collections (
    collection_id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    publisher VARCHAR(100),
    series_order INTEGER,
    total_volumes INTEGER,
    start_year INTEGER,
    end_year INTEGER,
    status VARCHAR(50) CHECK (status IN ('ONGOING', 'COMPLETED', 'DISCONTINUED')),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for mapping books to collections
CREATE TABLE book_collection_items (
    collection_item_id SERIAL PRIMARY KEY,
    book_id INTEGER REFERENCES books(book_id),
    collection_id INTEGER REFERENCES book_collections(collection_id),
    volume_number INTEGER,
    sequence_number INTEGER,
    is_special_edition BOOLEAN DEFAULT false,
    notes TEXT,
    UNIQUE(collection_id, volume_number)
);

-- Table for managing library branches
CREATE TABLE library_branches (
    branch_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    manager_id INTEGER REFERENCES staff(staff_id),
    opening_hours JSONB,
    facilities JSONB,
    status VARCHAR(50) CHECK (status IN ('ACTIVE', 'CLOSED', 'RENOVATING', 'TEMPORARY_CLOSED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for managing book inventory across branches
CREATE TABLE branch_inventory (
    inventory_id SERIAL PRIMARY KEY,
    branch_id INTEGER REFERENCES library_branches(branch_id),
    book_id INTEGER REFERENCES books(book_id),
    total_copies INTEGER NOT NULL,
    available_copies INTEGER NOT NULL,
    lost_copies INTEGER DEFAULT 0,
    damaged_copies INTEGER DEFAULT 0,
    last_inventory_date TIMESTAMP,
    shelf_location VARCHAR(50),
    status VARCHAR(50) CHECK (status IN ('ACTIVE', 'LOW_STOCK', 'OUT_OF_STOCK', 'DISCONTINUED')),
    UNIQUE(branch_id, book_id)
);

-- Table for managing patron memberships and subscription plans
CREATE TABLE membership_plans (
    plan_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    duration_months INTEGER NOT NULL,
    max_loans INTEGER,
    max_reservations INTEGER,
    loan_duration_days INTEGER,
    reservation_duration_days INTEGER,
    fine_rate DECIMAL(5,2),
    price DECIMAL(10,2),
    benefits JSONB,
    status VARCHAR(50) CHECK (status IN ('ACTIVE', 'DISCONTINUED', 'PROMOTIONAL')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for tracking patron membership history
CREATE TABLE patron_memberships (
    membership_id SERIAL PRIMARY KEY,
    patron_id INTEGER REFERENCES patrons(patron_id),
    plan_id INTEGER REFERENCES membership_plans(plan_id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    payment_status VARCHAR(50) CHECK (status IN ('PAID', 'PENDING', 'FAILED', 'REFUNDED')),
    payment_method VARCHAR(50),
    payment_reference VARCHAR(100),
    auto_renewal BOOLEAN DEFAULT false,
    status VARCHAR(50) CHECK (status IN ('ACTIVE', 'EXPIRED', 'CANCELLED', 'SUSPENDED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for managing inter-library loans
CREATE TABLE interlibrary_loans (
    ill_id SERIAL PRIMARY KEY,
    requesting_branch_id INTEGER REFERENCES library_branches(branch_id),
    providing_institution VARCHAR(200) NOT NULL,
    book_title VARCHAR(200) NOT NULL,
    isbn VARCHAR(13),
    patron_id INTEGER REFERENCES patrons(patron_id),
    request_date TIMESTAMP NOT NULL,
    expected_arrival_date DATE,
    actual_arrival_date DATE,
    return_due_date DATE,
    actual_return_date DATE,
    cost DECIMAL(10,2),
    status VARCHAR(50) CHECK (status IN ('REQUESTED', 'APPROVED', 'DENIED', 'IN_TRANSIT', 'RECEIVED', 'RETURNED', 'OVERDUE')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for managing library programs and workshops
CREATE TABLE library_programs (
    program_id SERIAL PRIMARY KEY,
    branch_id INTEGER REFERENCES library_branches(branch_id),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    program_type VARCHAR(50) CHECK (program_type IN ('WORKSHOP', 'COURSE', 'READING_GROUP', 'SEMINAR', 'EXHIBITION')),
    start_date DATE,
    end_date DATE,
    session_schedule JSONB,
    max_participants INTEGER,
    min_age INTEGER,
    max_age INTEGER,
    registration_deadline DATE,
    instructor_id INTEGER REFERENCES staff(staff_id),
    materials_provided JSONB,
    cost DECIMAL(10,2),
    status VARCHAR(50) CHECK (status IN ('DRAFT', 'PUBLISHED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for managing program registrations
CREATE TABLE program_registrations (
    registration_id SERIAL PRIMARY KEY,
    program_id INTEGER REFERENCES library_programs(program_id),
    patron_id INTEGER REFERENCES patrons(patron_id),
    registration_date TIMESTAMP NOT NULL,
    payment_status VARCHAR(50) CHECK (status IN ('PAID', 'PENDING', 'WAIVED', 'REFUNDED')),
    attendance_log JSONB,
    completion_status VARCHAR(50) CHECK (status IN ('REGISTERED', 'IN_PROGRESS', 'COMPLETED', 'DROPPED')),
    feedback_rating INTEGER CHECK (feedback_rating BETWEEN 1 AND 5),
    feedback_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(program_id, patron_id)
);

