-- Real Estate Developers Platform - Database Schema
-- PostgreSQL

-- Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================
-- USERS TABLE
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    user_type VARCHAR(50) NOT NULL CHECK (user_type IN ('buyer', 'investor', 'developer', 'admin')),
    profile_picture_url TEXT,
    location VARCHAR(255),
    bio TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    overall_rating DECIMAL(3, 2) DEFAULT 0,
    total_ratings INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    
    -- Indexes
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_users_is_verified ON users(is_verified);

-- ============================================
-- DEVELOPERS TABLE
-- ============================================
CREATE TABLE developers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    company_registration_number VARCHAR(100) UNIQUE NOT NULL,
    license_number VARCHAR(100) UNIQUE NOT NULL,
    years_experience INT NOT NULL CHECK (years_experience >= 0),
    total_projects INT DEFAULT 0,
    completed_projects INT DEFAULT 0,
    total_revenue DECIMAL(15, 2) DEFAULT 0,
    website_url TEXT,
    company_description TEXT,
    
    -- Verification Fields
    verification_status VARCHAR(50) DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected')),
    verification_document_url TEXT,
    verification_notes TEXT,
    verified_at TIMESTAMP,
    verified_by_admin_id UUID REFERENCES users(id),
    
    -- Ratings
    average_rating DECIMAL(3, 2) DEFAULT 0,
    total_rating_count INT DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_developers_user_id ON developers(user_id);
CREATE INDEX idx_developers_verification_status ON developers(verification_status);
CREATE INDEX idx_developers_average_rating ON developers(average_rating DESC);

-- ============================================
-- PROJECTS TABLE
-- ============================================
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    developer_id UUID NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    location VARCHAR(255) NOT NULL,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    
    -- Project Details
    project_type VARCHAR(50) NOT NULL CHECK (project_type IN ('residential', 'commercial', 'mixed', 'industrial')),
    total_units INT NOT NULL CHECK (total_units > 0),
    available_units INT NOT NULL CHECK (available_units >= 0),
    
    -- Pricing
    price_min DECIMAL(15, 2),
    price_max DECIMAL(15, 2),
    currency VARCHAR(3) DEFAULT 'SAR',
    
    -- Timeline
    start_date DATE,
    completion_date DATE,
    
    -- Media
    images JSONB DEFAULT '[]', -- Array of URLs
    documents JSONB DEFAULT '[]', -- Array of URLs
    
    -- Status
    status VARCHAR(50) DEFAULT 'planning' CHECK (status IN ('planning', 'construction', 'completed', 'available', 'sold_out')),
    
    -- Ratings
    average_rating DECIMAL(3, 2) DEFAULT 0,
    total_rating_count INT DEFAULT 0,
    
    -- Analytics
    view_count INT DEFAULT 0,
    favorite_count INT DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_featured BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_projects_developer_id ON projects(developer_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_project_type ON projects(project_type);
CREATE INDEX idx_projects_location ON projects(location);
CREATE INDEX idx_projects_average_rating ON projects(average_rating DESC);
CREATE INDEX idx_projects_created_at ON projects(created_at DESC);

-- ============================================
-- RATINGS & REVIEWS TABLE
-- ============================================
CREATE TABLE ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    developer_id UUID REFERENCES developers(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    
    -- Rating Details
    rating_value INT NOT NULL CHECK (rating_value BETWEEN 1 AND 5),
    title VARCHAR(255) NOT NULL,
    comment TEXT NOT NULL,
    
    -- Experience
    experience_type VARCHAR(50) NOT NULL CHECK (experience_type IN ('buyer', 'investor', 'tenant', 'neighbor')),
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    
    -- Additional Info
    pros JSONB DEFAULT '[]', -- Array of strings
    cons JSONB DEFAULT '[]', -- Array of strings
    images JSONB DEFAULT '[]', -- Array of URLs
    
    -- Engagement
    helpful_count INT DEFAULT 0,
    unhelpful_count INT DEFAULT 0,
    
    -- Moderation
    is_approved BOOLEAN DEFAULT TRUE,
    is_flagged BOOLEAN DEFAULT FALSE,
    flag_reason VARCHAR(255),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Ensure at least one target (developer or project)
    CONSTRAINT check_rating_target CHECK (developer_id IS NOT NULL OR project_id IS NOT NULL)
);

CREATE INDEX idx_ratings_reviewer_id ON ratings(reviewer_id);
CREATE INDEX idx_ratings_developer_id ON ratings(developer_id);
CREATE INDEX idx_ratings_project_id ON ratings(project_id);
CREATE INDEX idx_ratings_rating_value ON ratings(rating_value);
CREATE INDEX idx_ratings_created_at ON ratings(created_at DESC);

-- ============================================
-- TRANSACTIONS TABLE
-- ============================================
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    buyer_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    developer_id UUID NOT NULL REFERENCES developers(id) ON DELETE SET NULL,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE SET NULL,
    
    -- Transaction Details
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) DEFAULT 'SAR',
    
    -- Type & Status
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('reservation', 'payment', 'full_purchase')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'cancelled', 'disputed', 'refunded')),
    
    -- Payment Info
    payment_method VARCHAR(50) CHECK (payment_method IN ('bank_transfer', 'credit_card', 'debit_card', 'installment', 'wallet')),
    stripe_payment_id VARCHAR(255),
    
    -- Dates
    payment_date TIMESTAMP,
    completion_date TIMESTAMP,
    
    -- Documents
    documents JSONB DEFAULT '[]', -- Array of URLs
    
    -- Notes
    notes TEXT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transactions_buyer_id ON transactions(buyer_id);
CREATE INDEX idx_transactions_developer_id ON transactions(developer_id);
CREATE INDEX idx_transactions_project_id ON transactions(project_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);

-- ============================================
-- MESSAGES TABLE
-- ============================================
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
    
    -- Message Content
    subject VARCHAR(255),
    content TEXT NOT NULL,
    attachments JSONB DEFAULT '[]', -- Array of URLs
    
    -- Read Status
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX idx_messages_is_read ON messages(is_read);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX idx_messages_conversation ON messages(sender_id, receiver_id);

-- ============================================
-- FAVORITES TABLE
-- ============================================
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Ensure unique user-project pairs
    UNIQUE(user_id, project_id)
);

CREATE INDEX idx_favorites_user_id ON favorites(user_id);
CREATE INDEX idx_favorites_project_id ON favorites(project_id);

-- ============================================
-- NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Notification Details
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- 'rating', 'message', 'transaction', 'project', etc.
    related_resource_id UUID,
    related_resource_type VARCHAR(50),
    
    -- Status
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- ============================================
-- AUDIT LOG TABLE
-- ============================================
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(255) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_entity_type ON audit_logs(entity_type);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);

-- ============================================
-- VERIFICATION DOCUMENTS TABLE
-- ============================================
CREATE TABLE verification_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    developer_id UUID NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    
    document_type VARCHAR(100) NOT NULL, -- 'license', 'registration', 'insurance', etc.
    document_url TEXT NOT NULL,
    document_name VARCHAR(255) NOT NULL,
    file_size INT,
    mime_type VARCHAR(100),
    
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    reviewed_at TIMESTAMP,
    reviewed_by_admin_id UUID REFERENCES users(id),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_verification_documents_developer_id ON verification_documents(developer_id);
CREATE INDEX idx_verification_documents_status ON verification_documents(status);

-- ============================================
-- TRIGGERS FOR UPDATED_AT
-- ============================================
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to users table
CREATE TRIGGER users_update_timestamp BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Apply trigger to developers table
CREATE TRIGGER developers_update_timestamp BEFORE UPDATE ON developers
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Apply trigger to projects table
CREATE TRIGGER projects_update_timestamp BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Apply trigger to ratings table
CREATE TRIGGER ratings_update_timestamp BEFORE UPDATE ON ratings
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Apply trigger to transactions table
CREATE TRIGGER transactions_update_timestamp BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Apply trigger to messages table
CREATE TRIGGER messages_update_timestamp BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Apply trigger to verification_documents table
CREATE TRIGGER verification_documents_update_timestamp BEFORE UPDATE ON verification_documents
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================
-- VIEWS FOR ANALYTICS
-- ============================================

-- Developer Statistics View
CREATE VIEW developer_statistics AS
SELECT 
    d.id,
    d.company_name,
    COUNT(DISTINCT p.id) as total_projects,
    COUNT(DISTINCT CASE WHEN p.status = 'completed' THEN p.id END) as completed_projects,
    COUNT(DISTINCT CASE WHEN p.status = 'construction' THEN p.id END) as under_construction,
    AVG(r.rating_value)::DECIMAL(3, 2) as average_rating,
    COUNT(DISTINCT r.id) as total_ratings,
    COUNT(DISTINCT t.id) as total_transactions,
    COALESCE(SUM(t.amount), 0) as total_revenue
FROM developers d
LEFT JOIN projects p ON d.id = p.developer_id
LEFT JOIN ratings r ON d.id = r.developer_id
LEFT JOIN transactions t ON d.id = t.developer_id AND t.status = 'completed'
GROUP BY d.id, d.company_name;

-- Project Statistics View
CREATE VIEW project_statistics AS
SELECT 
    p.id,
    p.title,
    p.developer_id,
    p.status,
    p.available_units,
    p.total_units,
    ROUND((p.available_units::FLOAT / p.total_units) * 100, 2) as availability_percentage,
    AVG(r.rating_value)::DECIMAL(3, 2) as average_rating,
    COUNT(DISTINCT r.id) as total_ratings,
    COUNT(DISTINCT f.id) as favorite_count,
    p.view_count
FROM projects p
LEFT JOIN ratings r ON p.id = r.project_id
LEFT JOIN favorites f ON p.id = f.project_id
GROUP BY p.id, p.title, p.developer_id, p.status, p.available_units, p.total_units, p.view_count;

-- ============================================
-- STORED PROCEDURES
-- ============================================

-- Calculate and update developer rating
CREATE OR REPLACE FUNCTION update_developer_rating(developer_id UUID)
RETURNS TABLE(average_rating DECIMAL, total_count INT) AS $$
BEGIN
    UPDATE developers
    SET average_rating = (
        SELECT COALESCE(AVG(rating_value)::DECIMAL(3, 2), 0)
        FROM ratings
        WHERE developer_id = $1
    ),
    total_rating_count = (
        SELECT COUNT(*)
        FROM ratings
        WHERE developer_id = $1
    )
    WHERE id = $1;
    
    RETURN QUERY
    SELECT d.average_rating, d.total_rating_count
    FROM developers d
    WHERE d.id = $1;
END;
$$ LANGUAGE plpgsql;

-- Calculate and update project rating
CREATE OR REPLACE FUNCTION update_project_rating(project_id UUID)
RETURNS TABLE(average_rating DECIMAL, total_count INT) AS $$
BEGIN
    UPDATE projects
    SET average_rating = (
        SELECT COALESCE(AVG(rating_value)::DECIMAL(3, 2), 0)
        FROM ratings
        WHERE project_id = $1
    ),
    total_rating_count = (
        SELECT COUNT(*)
        FROM ratings
        WHERE project_id = $1
    )
    WHERE id = $1;
    
    RETURN QUERY
    SELECT p.average_rating, p.total_rating_count
    FROM projects p
    WHERE p.id = $1;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SAMPLE DATA (for testing)
-- ============================================

-- Note: This is commented out by default. Uncomment to seed data.
/*

-- Insert sample users
INSERT INTO users (email, password_hash, full_name, user_type) VALUES
('buyer@example.com', 'hashed_password', 'Ahmed Buyer', 'buyer'),
('investor@example.com', 'hashed_password', 'Fatima Investor', 'investor'),
('developer@example.com', 'hashed_password', 'Mohammed Developer', 'developer');

*/

-- ============================================
-- Grant permissions (for production)
-- ============================================
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;
