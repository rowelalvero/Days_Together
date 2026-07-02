-- Migration: Create User Notification Preferences Table
-- Created: 2026-07-02

-- 1. CREATE PREFERENCES TABLE
CREATE TABLE IF NOT EXISTS public.user_notification_preferences (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    chat_enabled boolean DEFAULT true NOT NULL,
    bucket_list_enabled boolean DEFAULT true NOT NULL,
    love_meter_enabled boolean DEFAULT true NOT NULL,
    daily_prompt_enabled boolean DEFAULT true NOT NULL,
    doodle_notes_enabled boolean DEFAULT true NOT NULL,
    timeline_enabled boolean DEFAULT true NOT NULL,
    time_capsule_enabled boolean DEFAULT true NOT NULL,
    calendar_enabled boolean DEFAULT true NOT NULL,
    love_notes_enabled boolean DEFAULT true NOT NULL,
    vault_enabled boolean DEFAULT true NOT NULL,
    gifts_enabled boolean DEFAULT true NOT NULL,
    relationship_enabled boolean DEFAULT true NOT NULL,
    memories_enabled boolean DEFAULT true NOT NULL,
    mute_all boolean DEFAULT false NOT NULL,
    quiet_hours_enabled boolean DEFAULT false NOT NULL,
    quiet_hours_start text DEFAULT '22:00' NOT NULL,
    quiet_hours_end text DEFAULT '07:00' NOT NULL,
    sound_enabled boolean DEFAULT true NOT NULL,
    vibration_enabled boolean DEFAULT true NOT NULL,
    badge_count_enabled boolean DEFAULT true NOT NULL,
    timezone text DEFAULT 'UTC' NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. ENABLE ROW LEVEL SECURITY
ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;

-- 3. CREATE RLS POLICIES
DROP POLICY IF EXISTS "Allow select for own preferences" ON public.user_notification_preferences;
CREATE POLICY "Allow select for own preferences" ON public.user_notification_preferences
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow update for own preferences" ON public.user_notification_preferences;
CREATE POLICY "Allow update for own preferences" ON public.user_notification_preferences
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow insert for own preferences" ON public.user_notification_preferences;
CREATE POLICY "Allow insert for own preferences" ON public.user_notification_preferences
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- 4. CREATE TRIGGER FUNCTION TO GENERATE DEFAULT PREFERENCES FOR NEW USERS
CREATE OR REPLACE FUNCTION public.handle_new_user_notification_preferences()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.user_notification_preferences (user_id)
    VALUES (new.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. BIND TRIGGER
DROP TRIGGER IF EXISTS on_auth_user_created_preferences ON public.users;
CREATE TRIGGER on_auth_user_created_preferences
    AFTER INSERT ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_notification_preferences();

-- 6. INSERT PREFERENCES FOR EXISTING USERS
INSERT INTO public.user_notification_preferences (user_id)
SELECT id FROM public.users
ON CONFLICT (user_id) DO NOTHING;
