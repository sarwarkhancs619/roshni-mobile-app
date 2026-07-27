-- 1. Add assigned_house_id column to existing friends table
ALTER TABLE public.friends 
ADD COLUMN IF NOT EXISTS assigned_house_id TEXT DEFAULT 'amin_house';

-- 2. Add house constraints check
ALTER TABLE public.friends DROP CONSTRAINT IF EXISTS friends_assigned_house_id_check;
ALTER TABLE public.friends ADD CONSTRAINT friends_assigned_house_id_check CHECK (assigned_house_id IN ('amin_house', 'roshni_house'));

-- 3. Update workshop check constraints to include 'woodwork' instead of 'agro'
ALTER TABLE public.friends DROP CONSTRAINT IF EXISTS friends_assigned_workshop_id_check;
ALTER TABLE public.friends ADD CONSTRAINT friends_assigned_workshop_id_check CHECK (assigned_workshop_id IN ('bakery', 'woodwork', 'farming', 'textile', 'artwork'));

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('admin', 'workshop_staff', 'physiotherapist', 'speech_therapist', 'medical_officer', 'house_staff'));

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_workshop_id_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_workshop_id_check CHECK (workshop_id IN ('bakery', 'woodwork', 'farming', 'textile', 'artwork', 'amin_house', 'roshni_house'));

ALTER TABLE public.activities DROP CONSTRAINT IF EXISTS activities_workshop_id_check;
ALTER TABLE public.activities ADD CONSTRAINT activities_workshop_id_check CHECK (workshop_id IN ('bakery', 'woodwork', 'farming', 'textile', 'artwork'));

ALTER TABLE public.skills DROP CONSTRAINT IF EXISTS skills_workshop_id_check;
ALTER TABLE public.skills ADD CONSTRAINT skills_workshop_id_check CHECK (workshop_id IN ('bakery', 'woodwork', 'farming', 'textile', 'artwork'));
