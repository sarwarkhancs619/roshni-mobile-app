-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS TABLE (PROFILES)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'workshop_staff', 'physiotherapist', 'speech_therapist', 'medical_officer', 'house_staff')),
  workshop_id TEXT CHECK (workshop_id IN ('bakery', 'woodwork', 'farming', 'textile', 'artwork', 'amin_house', 'roshni_house')),
  is_active BOOLEAN DEFAULT TRUE,
  phone_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 2. FRIENDS TABLE
CREATE TABLE IF NOT EXISTS public.friends (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  registration_number TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  photo_url TEXT,
  date_of_birth DATE NOT NULL,
  gender TEXT NOT NULL CHECK (gender IN ('male', 'female', 'other')),
  blood_group TEXT NOT NULL,
  cnic_or_bform TEXT,
  admission_date DATE NOT NULL,
  assigned_workshop_id TEXT NOT NULL CHECK (assigned_workshop_id IN ('bakery', 'woodwork', 'farming', 'textile', 'artwork')),
  assigned_house_id TEXT NOT NULL CHECK (assigned_house_id IN ('amin_house', 'roshni_house')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'graduated', 'suspended')),
  
  -- Guardian Details
  guardian_name TEXT NOT NULL,
  guardian_relation TEXT NOT NULL,
  guardian_phone TEXT NOT NULL,
  guardian_email TEXT,
  guardian_address TEXT NOT NULL,
  
  -- Emergency Contact
  emergency_name TEXT NOT NULL,
  emergency_relation TEXT NOT NULL,
  emergency_phone TEXT NOT NULL,
  
  medical_notes_summary TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS public.attendance (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  friend_id UUID REFERENCES public.friends(id) ON DELETE CASCADE,
  date DATE DEFAULT CURRENT_DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'leave', 'half_day')),
  marked_by UUID REFERENCES public.profiles(id),
  remarks TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(friend_id, date)
);

-- 4. DAILY ACTIVITIES TABLE
CREATE TABLE IF NOT EXISTS public.activities (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  friend_id UUID REFERENCES public.friends(id) ON DELETE CASCADE,
  workshop_id TEXT NOT NULL CHECK (workshop_id IN ('bakery', 'woodwork', 'farming', 'textile', 'artwork')),
  date DATE DEFAULT CURRENT_DATE NOT NULL,
  mood TEXT CHECK (mood IN ('excellent', 'good', 'neutral', 'agitated', 'withdrawn')),
  participation INT CHECK (participation BETWEEN 1 AND 5),
  communication INT CHECK (communication BETWEEN 1 AND 5),
  independence INT CHECK (independence BETWEEN 1 AND 5),
  task_completion INT CHECK (task_completion BETWEEN 1 AND 5),
  behavior_notes TEXT,
  general_notes TEXT,
  photo_urls TEXT[], 
  marked_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 5. SKILLS EVALUATION TABLE
CREATE TABLE IF NOT EXISTS public.skills (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  friend_id UUID REFERENCES public.friends(id) ON DELETE CASCADE,
  workshop_id TEXT NOT NULL CHECK (workshop_id IN ('bakery', 'woodwork', 'farming', 'textile', 'artwork')),
  skill_name TEXT NOT NULL,
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  assessed_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 6. IEP MODULE
CREATE TABLE IF NOT EXISTS public.iep (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  friend_id UUID REFERENCES public.friends(id) ON DELETE CASCADE,
  academic_year TEXT NOT NULL,
  baseline TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.iep_goals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  iep_id UUID REFERENCES public.iep(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  objectives TEXT NOT NULL,
  strategies TEXT NOT NULL,
  target_date DATE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'discontinued')),
  progress_percentage INT DEFAULT 0 CHECK (progress_percentage BETWEEN 0 AND 100)
);

-- 7. PHYSIOTHERAPY RECORD
CREATE TABLE IF NOT EXISTS public.physiotherapy_assessments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  friend_id UUID REFERENCES public.friends(id) ON DELETE CASCADE,
  therapist_id UUID REFERENCES public.profiles(id),
  range_of_motion TEXT,
  strength TEXT,
  balance TEXT,
  mobility TEXT,
  treatment_goals TEXT,
  exercises TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.physiotherapy_sessions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  assessment_id UUID REFERENCES public.physiotherapy_assessments(id) ON DELETE CASCADE,
  date DATE DEFAULT CURRENT_DATE NOT NULL,
  duration_minutes INT NOT NULL,
  notes TEXT,
  performance_rating INT CHECK (performance_rating BETWEEN 1 AND 5),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 8. SPEECH THERAPY RECORD
CREATE TABLE IF NOT EXISTS public.speech_assessments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  friend_id UUID REFERENCES public.friends(id) ON DELETE CASCADE,
  therapist_id UUID REFERENCES public.profiles(id),
  speech_skills TEXT,
  language_development TEXT,
  communication_goals TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.speech_sessions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  assessment_id UUID REFERENCES public.speech_assessments(id) ON DELETE CASCADE,
  date DATE DEFAULT CURRENT_DATE NOT NULL,
  notes TEXT,
  progress_description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 9. CLINICAL MEDICAL RECORDS
CREATE TABLE IF NOT EXISTS public.medical_records (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  friend_id UUID REFERENCES public.friends(id) ON DELETE CASCADE,
  doctor_id UUID REFERENCES public.profiles(id),
  allergies TEXT[],
  vaccinations TEXT[],
  medical_history TEXT,
  clinical_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.medical_prescriptions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  record_id UUID REFERENCES public.medical_records(id) ON DELETE CASCADE,
  date DATE DEFAULT CURRENT_DATE NOT NULL,
  medication_name TEXT NOT NULL,
  dosage TEXT NOT NULL,
  frequency TEXT NOT NULL,
  duration TEXT NOT NULL,
  instructions TEXT
);

CREATE TABLE IF NOT EXISTS public.medical_vitals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  record_id UUID REFERENCES public.medical_records(id) ON DELETE CASCADE,
  date TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  blood_pressure TEXT NOT NULL,
  heart_rate INT NOT NULL,
  temperature NUMERIC NOT NULL,
  weight NUMERIC NOT NULL
);

-- 10. DOCUMENTS METADATA
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  friend_id UUID REFERENCES public.friends(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('medical_report', 'certificate', 'consent_form', 'assessment')),
  storage_path TEXT NOT NULL,
  uploaded_by UUID REFERENCES public.profiles(id),
  uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 11. READ-ONLY AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  user_id UUID,
  user_email TEXT,
  action TEXT NOT NULL,
  details TEXT
);

-- INSERT DUMMY DATA FOR FRIENDS
INSERT INTO public.friends (
  id, registration_number, full_name, photo_url, date_of_birth, gender, blood_group, 
  cnic_or_bform, admission_date, assigned_workshop_id, assigned_house_id, status, 
  guardian_name, guardian_relation, guardian_phone, guardian_email, guardian_address, 
  emergency_name, emergency_relation, emergency_phone, medical_notes_summary
) VALUES 
(
  '00000000-0000-0000-0000-000000000001', 'RAMS-2026-0001', 'Zainab Fatima', 
  'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150', '2004-03-14', 'female', 'O+', 
  '35201-1234567-8', '2023-01-10', 'bakery', 'amin_house', 'active', 
  'Imran Fatima', 'Father', '0300-1234567', 'imran@example.com', 'Model Town, Lahore', 
  'Imran Fatima', 'Father', '0300-1234567', 'Mild developmental delay. Requires supervision during baking mixing processes. No allergies.'
),
(
  '00000000-0000-0000-0000-000000000002', 'RAMS-2026-0002', 'Ali Raza', 
  'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150', '2001-08-22', 'male', 'B+', 
  '35202-8765432-1', '2022-06-15', 'woodwork', 'roshni_house', 'active', 
  'Muhammad Raza', 'Father', '0321-7654321', 'raza@example.com', 'Johar Town, Lahore', 
  'Khadija Bibi', 'Mother', '0322-1122334', 'Down Syndrome. Highly active, loves woodwork. Prefers assembling and carving tasks. Monitor hydration.'
),
(
  '00000000-0000-0000-0000-000000000003', 'RAMS-2026-0003', 'Usman Tariq', 
  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150', '1998-11-05', 'male', 'A-', 
  '35201-9988776-5', '2021-09-01', 'farming', 'amin_house', 'active', 
  'Tariq Mahmood', 'Father', '0333-4455667', 'tariq@example.com', 'Gulberg, Lahore', 
  'Tariq Mahmood', 'Father', '0333-4455667', 'Autism spectrum. Sensitive to loud noises. Enjoys farming/composting activities.'
),
(
  '00000000-0000-0000-0000-000000000004', 'RAMS-2026-0004', 'Ayesha Bibi', 
  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150', '2002-05-30', 'female', 'AB+', 
  '35201-5544332-9', '2024-02-20', 'textile', 'roshni_house', 'active', 
  'Zubaida Bibi', 'Mother', '0312-9988776', 'zubaida@example.com', 'Faisal Town, Lahore', 
  'Sajid Ali', 'Brother', '0315-6677889', 'Speech impairment, mild cognitive delay. Excellent focus in stitching and thread cutting.'
),
(
  '00000000-0000-0000-0000-000000000005', 'RAMS-2026-0005', 'Bilal Mustafa', 
  'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150', '2005-01-19', 'male', 'O-', 
  '35203-1122334-5', '2025-04-01', 'artwork', 'roshni_house', 'active', 
  'Mustafa Qureshi', 'Father', '0300-8889990', 'mustafa@example.com', 'DHA Phase 5, Lahore', 
  'Mustafa Qureshi', 'Father', '0300-8889990', 'ADHD and cognitive challenge. Highly creative in painting. Requires calming environments.'
)
ON CONFLICT (id) DO NOTHING;
