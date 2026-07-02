-- Migration: Create Relationship Activities Table and Triggers
-- Created: 2026-07-02

-- 1. CREATE RELATIONSHIP ACTIVITIES TABLE
CREATE TABLE IF NOT EXISTS public.relationship_activities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id uuid NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    actor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    actor_name text NOT NULL,
    activity_type text NOT NULL,
    feature text NOT NULL,
    title text NOT NULL,
    subtitle text,
    icon text,
    timestamp timestamp with time zone DEFAULT now() NOT NULL,
    reference_id text,
    deep_link text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

-- 2. ENABLE ROW LEVEL SECURITY
ALTER TABLE public.relationship_activities ENABLE ROW LEVEL SECURITY;

-- 3. CREATE RLS POLICIES
DROP POLICY IF EXISTS "Allow select for own couple activities" ON public.relationship_activities;
CREATE POLICY "Allow select for own couple activities" ON public.relationship_activities
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE public.users.id = auth.uid() 
            AND public.users.couple_id = relationship_activities.couple_id
        )
    );

DROP POLICY IF EXISTS "Allow insert for own couple activities" ON public.relationship_activities;
CREATE POLICY "Allow insert for own couple activities" ON public.relationship_activities
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE public.users.id = auth.uid() 
            AND public.users.couple_id = relationship_activities.couple_id
        )
    );

DROP POLICY IF EXISTS "Allow delete for own couple activities" ON public.relationship_activities;
CREATE POLICY "Allow delete for own couple activities" ON public.relationship_activities
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE public.users.id = auth.uid() 
            AND public.users.couple_id = relationship_activities.couple_id
        )
    );

-- 4. CREATE INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_relationship_activities_couple_timestamp 
    ON public.relationship_activities (couple_id, timestamp DESC);

-- 5. TRIGGER FUNCTIONS FOR AUTOMATIC ACTIVITY LOGGING

-- A. Love Notes & Chat & Doodles
CREATE OR REPLACE FUNCTION public.log_love_notes_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_title text;
  v_subtitle text;
  v_activity_type text;
  v_feature text;
  v_icon text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = NEW.sender_id;

  IF NEW.type = 'chat' THEN
    v_feature := 'chat';
    v_activity_type := 'sent';
    v_title := v_actor_name || ' sent a message';
    v_subtitle := NEW.content;
    v_icon := '💬';
  ELSIF NEW.type = 'drawing' THEN
    v_feature := 'doodle_notes';
    v_activity_type := 'created';
    v_title := v_actor_name || ' shared a doodle';
    v_subtitle := 'Sketched a sweet doodle';
    v_icon := '🎨';
  ELSIF NEW.type = 'photo' THEN
    v_feature := 'love_notes';
    v_activity_type := 'created';
    v_title := v_actor_name || ' shared a photo';
    v_subtitle := 'Captured a beautiful moment';
    v_icon := '📷';
  ELSIF NEW.type = 'text' THEN
    v_feature := 'love_notes';
    v_activity_type := 'created';
    v_title := v_actor_name || ' sent a love note';
    v_subtitle := NEW.content;
    v_icon := '✍️';
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (NEW.couple_id, NEW.sender_id, COALESCE(v_actor_name, 'Partner'), v_activity_type, v_feature, v_title, v_subtitle, v_icon, NEW.id::text, v_feature);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_love_notes_inserted ON public.love_notes;
CREATE TRIGGER on_love_notes_inserted
  AFTER INSERT ON public.love_notes
  FOR EACH ROW EXECUTE FUNCTION public.log_love_notes_activity();

-- B. Bucket List
CREATE OR REPLACE FUNCTION public.log_bucket_list_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_title text;
  v_subtitle text;
  v_activity_type text;
  v_icon text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    v_activity_type := 'created';
    v_title := 'Added to bucket list';
    v_subtitle := 'Let''s do: ' || NEW.title;
    v_icon := '🪣';
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.is_completed = false AND NEW.is_completed = true THEN
      v_activity_type := 'completed';
      v_title := 'Bucket list completed';
      v_subtitle := 'We did: ' || NEW.title || ' 🎉';
      v_icon := '🎉';
    ELSE
      v_activity_type := 'updated';
      v_title := 'Bucket list item updated';
      v_subtitle := NEW.title;
      v_icon := '✏️';
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    v_activity_type := 'deleted';
    v_title := 'Bucket list item deleted';
    v_subtitle := OLD.title;
    v_icon := '🗑️';
    INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
    VALUES (OLD.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'bucket_list', v_title, v_subtitle, v_icon, OLD.id::text, 'bucket_list');
    RETURN OLD;
  END IF;

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (NEW.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'bucket_list', v_title, v_subtitle, v_icon, NEW.id::text, 'bucket_list');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_bucket_list_modified ON public.bucket_list;
CREATE TRIGGER on_bucket_list_modified
  AFTER INSERT OR UPDATE OR DELETE ON public.bucket_list
  FOR EACH ROW EXECUTE FUNCTION public.log_bucket_list_activity();

-- C. Calendar Events
CREATE OR REPLACE FUNCTION public.log_calendar_events_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_title text;
  v_subtitle text;
  v_activity_type text;
  v_icon text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    v_activity_type := 'created';
    v_title := 'Scheduled event';
    v_subtitle := NEW.title;
    v_icon := '📅';
  ELSIF TG_OP = 'UPDATE' THEN
    v_activity_type := 'updated';
    v_title := 'Event updated';
    v_subtitle := NEW.title;
    v_icon := '✏️';
  ELSIF TG_OP = 'DELETE' THEN
    v_activity_type := 'deleted';
    v_title := 'Event deleted';
    v_subtitle := OLD.title;
    v_icon := '🗑️';
    INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
    VALUES (OLD.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'calendar', v_title, v_subtitle, v_icon, OLD.id::text, 'calendar');
    RETURN OLD;
  END IF;

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (NEW.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'calendar', v_title, v_subtitle, v_icon, NEW.id::text, 'calendar');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_calendar_events_modified ON public.calendar_events;
CREATE TRIGGER on_calendar_events_modified
  AFTER INSERT OR UPDATE OR DELETE ON public.calendar_events
  FOR EACH ROW EXECUTE FUNCTION public.log_calendar_events_activity();

-- D. Time Capsules
CREATE OR REPLACE FUNCTION public.log_time_capsules_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_title text;
  v_subtitle text;
  v_activity_type text;
  v_icon text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    v_activity_type := 'created';
    v_title := 'Created a time capsule';
    v_subtitle := 'Locked until ' || to_char(NEW.open_date, 'Mon DD, YYYY');
    v_icon := '⏳';
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.is_opened = false AND NEW.is_opened = true THEN
      v_activity_type := 'updated';
      v_title := 'Opened a time capsule';
      v_subtitle := 'Opened a locked memory';
      v_icon := '🔓';
    ELSE
      v_activity_type := 'updated';
      v_title := 'Time capsule updated';
      v_subtitle := 'Modified time capsule settings';
      v_icon := '✏️';
    END IF;
  ELSE
    RETURN NULL;
  END IF;

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (COALESCE(NEW.couple_id, OLD.couple_id), auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'time_capsule', v_title, v_subtitle, v_icon, NEW.id::text, 'time_capsule');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_time_capsules_modified ON public.time_capsules;
CREATE TRIGGER on_time_capsules_modified
  AFTER INSERT OR UPDATE ON public.time_capsules
  FOR EACH ROW EXECUTE FUNCTION public.log_time_capsules_activity();

-- E. Vault Items (Privacy Preserving)
CREATE OR REPLACE FUNCTION public.log_vault_items_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_title text;
  v_subtitle text;
  v_activity_type text;
  v_icon text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    v_activity_type := 'created';
    v_title := v_actor_name || ' added something to the Vault';
    v_subtitle := 'Private item added';
    v_icon := '🔒';
  ELSIF TG_OP = 'DELETE' THEN
    v_activity_type := 'deleted';
    v_title := v_actor_name || ' removed something from the Vault';
    v_subtitle := 'Private item removed';
    v_icon := '🔒';
    INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
    VALUES (OLD.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'vault', v_title, v_subtitle, v_icon, OLD.id::text, 'vault');
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (NEW.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'vault', v_title, v_subtitle, v_icon, NEW.id::text, 'vault');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_vault_items_modified ON public.vault_items;
CREATE TRIGGER on_vault_items_modified
  AFTER INSERT OR DELETE ON public.vault_items
  FOR EACH ROW EXECUTE FUNCTION public.log_vault_items_activity();

-- F. Topic Cards & Likes
CREATE OR REPLACE FUNCTION public.log_topic_cards_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    IF NEW.is_custom = true THEN
      INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
      VALUES (NEW.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), 'created', 'topic_cards', 'Created a custom topic card', NEW.question, '🎴', NEW.id::text, 'topic_cards');
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_topic_cards_modified ON public.topic_cards;
CREATE TRIGGER on_topic_cards_modified
  AFTER INSERT ON public.topic_cards
  FOR EACH ROW EXECUTE FUNCTION public.log_topic_cards_activity();

CREATE OR REPLACE FUNCTION public.log_topic_card_likes_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_question text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = NEW.user_id;

  SELECT question INTO v_question
  FROM public.topic_cards
  WHERE id::text = NEW.card_id
  LIMIT 1;

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (NEW.couple_id, NEW.user_id, COALESCE(v_actor_name, 'Partner'), 'liked', 'topic_cards', v_actor_name || ' liked a topic card', COALESCE(v_question, 'Liked a question'), '❤️', NEW.card_id, 'topic_cards');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_topic_card_likes_inserted ON public.topic_card_likes;
CREATE TRIGGER on_topic_card_likes_inserted
  AFTER INSERT ON public.topic_card_likes
  FOR EACH ROW EXECUTE FUNCTION public.log_topic_card_likes_activity();

-- G. Gift Reminders
CREATE OR REPLACE FUNCTION public.log_gift_reminders_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_title text;
  v_subtitle text;
  v_activity_type text;
  v_icon text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    v_activity_type := 'created';
    v_title := 'Added a gift reminder';
    v_subtitle := NEW.title;
    v_icon := '🎁';
  ELSIF TG_OP = 'DELETE' THEN
    v_activity_type := 'deleted';
    v_title := 'Gift reminder deleted';
    v_subtitle := OLD.title;
    v_icon := '🗑️';
    INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
    VALUES (OLD.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'gifts', v_title, v_subtitle, v_icon, OLD.id::text, 'gifts');
    RETURN OLD;
  END IF;

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (NEW.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'gifts', v_title, v_subtitle, v_icon, NEW.id::text, 'gifts');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_gift_reminders_modified ON public.gift_reminders;
CREATE TRIGGER on_gift_reminders_modified
  AFTER INSERT OR DELETE ON public.gift_reminders
  FOR EACH ROW EXECUTE FUNCTION public.log_gift_reminders_activity();

-- H. Daily Moods
CREATE OR REPLACE FUNCTION public.log_moods_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_title text;
  v_subtitle text;
  v_activity_type text;
  v_icon text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = NEW.user_id;

  v_activity_type := 'updated';
  v_title := v_actor_name || ' updated their mood';
  v_subtitle := 'Today''s mood: ' || NEW.mood_score || '/10';
  v_icon := '❤️';

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (NEW.couple_id, NEW.user_id, COALESCE(v_actor_name, 'Partner'), v_activity_type, 'love_meter', v_title, v_subtitle, v_icon, NEW.id::text, 'love_meter');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_moods_modified ON public.moods;
CREATE TRIGGER on_moods_modified
  AFTER INSERT OR UPDATE ON public.moods
  FOR EACH ROW EXECUTE FUNCTION public.log_moods_activity();

-- I. Timeline Items (Memories)
CREATE OR REPLACE FUNCTION public.log_timeline_items_activity()
RETURNS trigger AS $$
DECLARE
  v_actor_name text;
  v_title text;
  v_subtitle text;
  v_activity_type text;
  v_icon text;
BEGIN
  SELECT COALESCE(name, display_name, 'Partner')
  INTO v_actor_name
  FROM public.users
  WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    v_activity_type := 'created';
    v_title := 'New memory added 📸';
    v_subtitle := NEW.title;
    v_icon := '📸';
  ELSIF TG_OP = 'UPDATE' THEN
    v_activity_type := 'updated';
    v_title := 'Memory updated ✏️';
    v_subtitle := NEW.title;
    v_icon := '✏️';
  ELSIF TG_OP = 'DELETE' THEN
    v_activity_type := 'deleted';
    v_title := 'Memory deleted 🗑️';
    v_subtitle := OLD.title;
    v_icon := '🗑️';
    INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
    VALUES (OLD.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'timeline', v_title, v_subtitle, v_icon, OLD.id::text, 'timeline');
    RETURN OLD;
  END IF;

  INSERT INTO public.relationship_activities (couple_id, actor_id, actor_name, activity_type, feature, title, subtitle, icon, reference_id, deep_link)
  VALUES (NEW.couple_id, auth.uid(), COALESCE(v_actor_name, 'Partner'), v_activity_type, 'timeline', v_title, v_subtitle, v_icon, NEW.id::text, 'timeline');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_timeline_items_modified ON public.timeline_items;
CREATE TRIGGER on_timeline_items_modified
  AFTER INSERT OR UPDATE OR DELETE ON public.timeline_items
  FOR EACH ROW EXECUTE FUNCTION public.log_timeline_items_activity();

