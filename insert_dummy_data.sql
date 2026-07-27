-- Insert mock friends
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
