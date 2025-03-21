# Library Management System - Legacy Project

## Description
This is a complex Library Management System implemented using PostgreSQL, showcasing advanced database design and complex business logic implemented through stored procedures. The system manages multiple library branches, book collections, patron memberships, events, programs, and inter-library loans. It includes sophisticated features such as inventory management, collection analysis, and membership plan optimization.

## Technologies and Languages
- PostgreSQL 14+
- PL/pgSQL
- PlantUML (for database schema visualization)

## Entity-Relationship Diagram

The following diagram shows the complete database schema with all entities and their relationships:

![Library Management System ER Diagram](LeXVP0_9sZq2YXdQvagFiAFEasZZkBPNHzVH3dnKxW61gBBIBJpXrOubvPGrCt7Mrn_Ssf7Vf2xVZlXQun655nK8yHuND30ldKFu8QKQPmjMLsUtCdQqXYREmffFqv78w7t9Y3ZJ15aZcOsvd0gAeB3K_v3GM8bbohum9uL7kssqNls4IyA40uZ6uI_GRoLy0vOtbJq3m00)

### Stored Procedures Documentation

#### Low Complexity Procedures

1. `create_patron`
   - Description: Creates a new patron record with basic information

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_first_name | Patron's first name | VARCHAR(50) | 'John' |
   | p_last_name | Patron's last name | VARCHAR(50) | 'Smith' |
   | p_email | Patron's email address | VARCHAR(100) | 'john.smith@email.com' |
   | p_phone | Patron's phone number | VARCHAR(20) | '555-0123' |
   | p_birth_date | Patron's date of birth | DATE | '1990-01-15' |

   Output Parameters: None

2. `update_book_availability`
   - Description: Updates the available copies count for a specific book

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_book_id | Unique identifier of the book | INTEGER | 1001 |
   | p_change | Number of copies to add (positive) or remove (negative) | INTEGER | -1 |

   Output Parameters: None
3. `register_for_event`
   - Description: Registers a patron for a library event and updates participant count

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_event_id | Unique identifier of the event | INTEGER | 5001 |
   | p_patron_id | Unique identifier of the patron | INTEGER | 2001 |

   Output Parameters: None

4. `add_book_review`
   - Description: Adds a new book review from a patron

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_book_id | Unique identifier of the book | INTEGER | 1001 |
   | p_patron_id | Unique identifier of the patron | INTEGER | 2001 |
   | p_rating | Rating score (1-5) | INTEGER | 4 |
   | p_review_text | Review content | TEXT | 'Great book, highly recommended!' |

   Output Parameters: None

5. `update_staff_status`
   - Description: Updates the status of a staff member

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_staff_id | Unique identifier of the staff member | INTEGER | 3001 |
   | p_new_status | New status value | VARCHAR(20) | 'ON_LEAVE' |

   Output Parameters: None

#### Medium Complexity Procedures

1. `process_book_loan`
   - Description: Processes a book loan request with validation checks

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_patron_id | Unique identifier of the patron | INTEGER | 2001 |
   | p_book_id | Unique identifier of the book | INTEGER | 1001 |
   | p_loan_days | Duration of the loan in days | INTEGER | 14 |

   Output Parameters: None

2. `process_book_return`
   - Description: Processes book return and calculates fines

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_loan_id | Unique identifier of the loan | INTEGER | 4001 |

   Output Parameters: None

3. `manage_event_registration`
   - Description: Manages event registration with capacity checking

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_event_id | Unique identifier of the event | INTEGER | 5001 |
   | p_patron_id | Unique identifier of the patron | INTEGER | 2001 |

   Output Parameters: None

4. `extend_loan_period`
   - Description: Extends loan period if conditions are met

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_loan_id | Unique identifier of the loan | INTEGER | 4001 |
   | p_extension_days | Number of days to extend | INTEGER | 7 |

   Output Parameters: None

5. `process_fine_payment`
   - Description: Processes payment for library fines

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_fine_id | Unique identifier of the fine | INTEGER | 6001 |
   | p_amount_paid | Amount being paid | DECIMAL(10,2) | 25.50 |

   Output Parameters: None

#### High Complexity Procedures

1. `generate_monthly_statistics`
   - Description: Generates comprehensive monthly statistics

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_year | Year for statistics | INTEGER | 2023 |
   | p_month | Month number (1-12) | INTEGER | 7 |

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | audit_log entry | JSON containing statistics | JSONB | {'total_loans': 150, 'active_patrons': 75} |

2. `generate_book_recommendations`
   - Description: Generates personalized book recommendations

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_patron_id | Unique identifier of the patron | INTEGER | 2001 |

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | recommendations_cursor | Cursor containing recommended books | REFCURSOR | {book_id: 1001, score: 0.85} |

3. `process_overdue_items`
   - Description: Automated system for processing overdue items

   Input Parameters: None

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | audit_log entries | Notification and fine records | JSONB | {'patron_id': 2001, 'fine_amount': 12.50} |

4. `manage_library_events`
   - Description: Complex event management system

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_action | Type of action to perform | VARCHAR | 'CANCEL_EVENT' |
   | p_event_id | Unique identifier of the event | INTEGER | 5001 |
   | p_event_data | Additional event parameters | JSONB | {'new_date': '2023-12-01'} |

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | audit_log entries | Event modification records | JSONB | {'action': 'CANCEL_EVENT', 'affected_registrations': 15} |

5. `analyze_and_manage_collections`
   - Description: Collection analysis and management system

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_collection_id | Unique identifier of collection (optional) | INTEGER | 7001 |
   | p_action | Type of analysis to perform | VARCHAR | 'ANALYZE_PERFORMANCE' |
   | p_params | Additional parameters | JSONB | {'analysis_period': 90} |

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | audit_log entries | Analysis results and recommendations | JSONB | {'popularity_rank': 0.85, 'recommended_actions': ['PROMOTE']} |

6. `analyze_membership_plans`
   - Description: Analyzes and optimizes membership plans

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_action | Type of analysis to perform | VARCHAR | 'OPTIMIZE_PRICING' |
   | p_params | Analysis parameters | JSONB | {'min_price': 10.00, 'max_price': 50.00} |

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | audit_log entries | Analysis results and recommendations | JSONB | {'plan_id': 8001, 'recommended_price': 29.99} |

7. `process_interlibrary_loan_request`
   - Description: Manages inter-library loan requests

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_requesting_branch_id | ID of requesting branch | INTEGER | 9001 |
   | p_patron_id | ID of requesting patron | INTEGER | 2001 |
   | p_book_title | Title of requested book | VARCHAR | 'Database Design Principles' |
   | p_isbn | ISBN of requested book | VARCHAR | '978-0-123456-78-9' |
   | p_providing_institution | Name of lending institution | VARCHAR | 'Central Library' |

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | ill_id | Generated inter-library loan ID | INTEGER | 10001 |

8. `manage_program_lifecycle`
   - Description: Manages library programs lifecycle

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_program_id | ID of the program | INTEGER | 11001 |
   | p_action | Lifecycle action to perform | VARCHAR | 'START_PROGRAM' |
   | p_params | Additional parameters | JSONB | {'session_date': '2023-12-01'} |

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | audit_log entries | Program status updates | JSONB | {'status': 'IN_PROGRESS', 'participants': 12} |

9. `manage_branch_inventory`
   - Description: Branch inventory management system

   Input Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | p_branch_id | ID of the branch | INTEGER | 9001 |
   | p_action | Inventory action to perform | VARCHAR | 'AUDIT_INVENTORY' |
   | p_params | Action parameters | JSONB | {'actual_count': {'book_id': 1001, 'count': 5}} |

   Output Parameters:
   | Name | Description | Type | Example Value |
   |------|-------------|------|---------------|
   | audit_log entries | Inventory reconciliation results | JSONB | {'discrepancies': 2, 'recommendations': ['REORDER']} |

## Implementation Notes
- All stored procedures include comprehensive error handling
- Complex operations are wrapped in transactions
- Audit logging is implemented for all major operations
- Business rules are centralized in stored procedures
- Data integrity is enforced through constraints and triggers
- Performance considerations are implemented through proper indexing and temporary tables

## Performance Considerations
- Temporary tables used for complex calculations
- Efficient data aggregation techniques
- Batch processing for large operations
- Strategic use of indexes
- Transaction management for data consistency

## Security Features
- Input parameter validation
- Error handling and logging
- Audit trail maintenance
- Status-based access control
- Transaction isolation

## Maintenance and Monitoring
- Comprehensive audit logging
- Performance metrics collection
- Error tracking and reporting
- Usage statistics gathering
- System health monitoring


