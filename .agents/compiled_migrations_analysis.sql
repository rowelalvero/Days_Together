-- FILE: 20260621000000_remote_schema.sql



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."get_user_couple_id"("user_id" "uuid") RETURNS "text"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT couple_id::text FROM public.users WHERE id = user_id;
$$;


ALTER FUNCTION "public"."get_user_couple_id"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_member_of_couple"("couple_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.couple_id = is_member_of_couple.couple_id
  );
END;
$$;


ALTER FUNCTION "public"."is_member_of_couple"("couple_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."bucket_list" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "couple_id" "uuid",
    "title" "text" NOT NULL,
    "is_completed" boolean DEFAULT false,
    "completed_at" timestamp with time zone,
    "order_index" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "scheduled_at" timestamp with time zone
);

ALTER TABLE ONLY "public"."bucket_list" REPLICA IDENTITY FULL;


ALTER TABLE "public"."bucket_list" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."calendar_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "couple_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "date" timestamp with time zone NOT NULL,
    "hour" integer,
    "minute" integer,
    "type" integer DEFAULT 4,
    "is_recurring_yearly" boolean DEFAULT false
);

ALTER TABLE ONLY "public"."calendar_events" REPLICA IDENTITY FULL;


ALTER TABLE "public"."calendar_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."couples" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "story_title" "text" DEFAULT 'Our Story'::"text",
    "start_date" timestamp with time zone,
    "start_time_hour" integer,
    "start_time_minute" integer,
    "is_premium" boolean DEFAULT false
);


ALTER TABLE "public"."couples" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_questions" (
    "date" "text" NOT NULL,
    "couple_id" "uuid" NOT NULL,
    "question" "text" NOT NULL,
    "answers" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."daily_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."gift_reminders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "couple_id" "uuid",
    "title" "text" NOT NULL,
    "date" timestamp with time zone NOT NULL,
    "reminder_days_before" integer[] DEFAULT '{30,14,7}'::integer[],
    "is_enabled" boolean DEFAULT true,
    "is_recurring_yearly" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "public"."gift_reminders" REPLICA IDENTITY FULL;


ALTER TABLE "public"."gift_reminders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."license_details" (
    "couple_id" "uuid" NOT NULL,
    "creator_id" "uuid",
    "your_name" "text",
    "partner_name" "text",
    "your_gender" "text",
    "partner_gender" "text",
    "your_phone" "text",
    "partner_phone" "text",
    "your_birthdate" timestamp with time zone,
    "partner_birthdate" timestamp with time zone,
    "your_address" "text",
    "partner_address" "text",
    "your_nationality" "text" DEFAULT 'Love Land'::"text",
    "partner_nationality" "text" DEFAULT 'Love Land'::"text",
    "your_weight" "text" DEFAULT '—'::"text",
    "partner_weight" "text" DEFAULT '—'::"text",
    "your_height" "text" DEFAULT '—'::"text",
    "partner_height" "text" DEFAULT '—'::"text",
    "your_blood_type" "text" DEFAULT '—'::"text",
    "partner_blood_type" "text" DEFAULT '—'::"text",
    "your_eye_color" "text" DEFAULT '—'::"text",
    "partner_eye_color" "text" DEFAULT '—'::"text",
    "your_conditions" "text" DEFAULT 'Madly in Love'::"text",
    "partner_conditions" "text" DEFAULT 'Madly in Love'::"text",
    "your_date_issued" timestamp with time zone,
    "partner_date_issued" timestamp with time zone,
    "your_signature" "text",
    "partner_signature" "text",
    "your_avatar_path" "text",
    "partner_avatar_path" "text"
);


ALTER TABLE "public"."license_details" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."love_notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "couple_id" "uuid",
    "type" "text" NOT NULL,
    "content" "text",
    "sender_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "background_color" integer,
    "image_url" "text"
);

ALTER TABLE ONLY "public"."love_notes" REPLICA IDENTITY FULL;


ALTER TABLE "public"."love_notes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."moods" (
    "id" "text" NOT NULL,
    "couple_id" "uuid",
    "user_id" "uuid",
    "date" "text" NOT NULL,
    "mood_score" integer DEFAULT 5,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "public"."moods" REPLICA IDENTITY FULL;


ALTER TABLE "public"."moods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pairing_codes" (
    "code" character varying(6) NOT NULL,
    "creator_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."pairing_codes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."time_capsules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "couple_id" "uuid",
    "message" "text" NOT NULL,
    "open_date" timestamp with time zone NOT NULL,
    "is_opened" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "public"."time_capsules" REPLICA IDENTITY FULL;


ALTER TABLE "public"."time_capsules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."timeline_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "couple_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "location" "text",
    "image_path" "text",
    "network_image_url" "text",
    "date" timestamp with time zone NOT NULL,
    "is_image_card" boolean DEFAULT false,
    "position" integer DEFAULT 0,
    "mood" "text" DEFAULT '😍'::"text",
    "photo_urls" "text"[] DEFAULT '{}'::"text"[],
    "is_pinned" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "comments" "jsonb" DEFAULT '[]'::"jsonb"
);

ALTER TABLE ONLY "public"."timeline_items" REPLICA IDENTITY FULL;


ALTER TABLE "public"."timeline_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."topic_cards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "couple_id" "uuid",
    "category" "text" NOT NULL,
    "question" "text" NOT NULL,
    "is_custom" boolean DEFAULT true,
    "liked_by_user_ids" "uuid"[] DEFAULT '{}'::"uuid"[]
);

ALTER TABLE ONLY "public"."topic_cards" REPLICA IDENTITY FULL;


ALTER TABLE "public"."topic_cards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_fcm_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "token" "text" NOT NULL,
    "device_type" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_fcm_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "display_name" "text",
    "couple_id" "uuid",
    "partner_id" "uuid"
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vault_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "couple_id" "uuid",
    "type" integer DEFAULT 0,
    "content" "text",
    "image_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "public"."vault_items" REPLICA IDENTITY FULL;


ALTER TABLE "public"."vault_items" OWNER TO "postgres";


ALTER TABLE ONLY "public"."bucket_list"
    ADD CONSTRAINT "bucket_list_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."calendar_events"
    ADD CONSTRAINT "calendar_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."couples"
    ADD CONSTRAINT "couples_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_questions"
    ADD CONSTRAINT "daily_questions_pkey" PRIMARY KEY ("date", "couple_id");



ALTER TABLE ONLY "public"."gift_reminders"
    ADD CONSTRAINT "gift_reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."license_details"
    ADD CONSTRAINT "license_details_pkey" PRIMARY KEY ("couple_id");



ALTER TABLE ONLY "public"."love_notes"
    ADD CONSTRAINT "love_notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moods"
    ADD CONSTRAINT "moods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pairing_codes"
    ADD CONSTRAINT "pairing_codes_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."time_capsules"
    ADD CONSTRAINT "time_capsules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."timeline_items"
    ADD CONSTRAINT "timeline_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."topic_cards"
    ADD CONSTRAINT "topic_cards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_fcm_tokens"
    ADD CONSTRAINT "user_fcm_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_fcm_tokens"
    ADD CONSTRAINT "user_fcm_tokens_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vault_items"
    ADD CONSTRAINT "vault_items_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_user_fcm_tokens_user_id" ON "public"."user_fcm_tokens" USING "btree" ("user_id");



ALTER TABLE ONLY "public"."bucket_list"
    ADD CONSTRAINT "bucket_list_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."calendar_events"
    ADD CONSTRAINT "calendar_events_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_questions"
    ADD CONSTRAINT "daily_questions_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."gift_reminders"
    ADD CONSTRAINT "gift_reminders_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."license_details"
    ADD CONSTRAINT "license_details_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."love_notes"
    ADD CONSTRAINT "love_notes_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."love_notes"
    ADD CONSTRAINT "love_notes_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moods"
    ADD CONSTRAINT "moods_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moods"
    ADD CONSTRAINT "moods_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pairing_codes"
    ADD CONSTRAINT "pairing_codes_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."time_capsules"
    ADD CONSTRAINT "time_capsules_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."timeline_items"
    ADD CONSTRAINT "timeline_items_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."topic_cards"
    ADD CONSTRAINT "topic_cards_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_fcm_tokens"
    ADD CONSTRAINT "user_fcm_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vault_items"
    ADD CONSTRAINT "vault_items_couple_id_fkey" FOREIGN KEY ("couple_id") REFERENCES "public"."couples"("id") ON DELETE CASCADE;



CREATE POLICY "Couple access to bucket_list" ON "public"."bucket_list" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to calendar_events" ON "public"."calendar_events" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to daily_questions" ON "public"."daily_questions" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to gift_reminders" ON "public"."gift_reminders" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to love_notes" ON "public"."love_notes" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to moods" ON "public"."moods" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to time_capsules" ON "public"."time_capsules" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to timeline_items" ON "public"."timeline_items" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to topic_cards" ON "public"."topic_cards" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Couple access to vault_items" ON "public"."vault_items" USING ("public"."is_member_of_couple"("couple_id"));



CREATE POLICY "Enable delete for authenticated users" ON "public"."pairing_codes" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete for couple members" ON "public"."couples" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "couples"."id")))));



CREATE POLICY "Enable delete for couple members" ON "public"."license_details" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "license_details"."couple_id")))));



CREATE POLICY "Enable delete for own profile" ON "public"."users" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "Enable insert for authenticated users" ON "public"."couples" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for couple members" ON "public"."license_details" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "license_details"."couple_id")))));



CREATE POLICY "Enable insert for creator" ON "public"."pairing_codes" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "creator_id"));



CREATE POLICY "Enable insert for own profile" ON "public"."users" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Enable select for authenticated users" ON "public"."pairing_codes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable select for authenticated users" ON "public"."users" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable select for couple members" ON "public"."couples" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "couples"."id")))));



CREATE POLICY "Enable select for couple members" ON "public"."license_details" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "license_details"."couple_id")))));



CREATE POLICY "Enable update for couple members" ON "public"."couples" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "couples"."id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "couples"."id")))));



CREATE POLICY "Enable update for couple members" ON "public"."license_details" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "license_details"."couple_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."couple_id" = "license_details"."couple_id")))));



CREATE POLICY "Enable update for creator" ON "public"."pairing_codes" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "creator_id")) WITH CHECK (("auth"."uid"() = "creator_id"));



CREATE POLICY "Enable update for own profile or pairing partner" ON "public"."users" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() = "id") OR ("id" IN ( SELECT "pairing_codes"."creator_id"
   FROM "public"."pairing_codes")))) WITH CHECK ((("auth"."uid"() = "id") OR ("id" IN ( SELECT "pairing_codes"."creator_id"
   FROM "public"."pairing_codes"))));



CREATE POLICY "Users can delete their own FCM tokens" ON "public"."user_fcm_tokens" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own FCM tokens" ON "public"."user_fcm_tokens" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own FCM tokens" ON "public"."user_fcm_tokens" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own FCM tokens" ON "public"."user_fcm_tokens" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."bucket_list" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."calendar_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."couples" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."gift_reminders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."license_details" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."love_notes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."moods" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pairing_codes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."time_capsules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."timeline_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."topic_cards" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_fcm_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vault_items" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."bucket_list";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."calendar_events";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."couples";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."daily_questions";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."gift_reminders";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."license_details";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."love_notes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."moods";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."pairing_codes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."time_capsules";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."timeline_items";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."topic_cards";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."users";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."vault_items";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."get_user_couple_id"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_couple_id"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_couple_id"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_member_of_couple"("couple_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_member_of_couple"("couple_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_member_of_couple"("couple_id" "uuid") TO "service_role";


















GRANT ALL ON TABLE "public"."bucket_list" TO "anon";
GRANT ALL ON TABLE "public"."bucket_list" TO "authenticated";
GRANT ALL ON TABLE "public"."bucket_list" TO "service_role";



GRANT ALL ON TABLE "public"."calendar_events" TO "anon";
GRANT ALL ON TABLE "public"."calendar_events" TO "authenticated";
GRANT ALL ON TABLE "public"."calendar_events" TO "service_role";



GRANT ALL ON TABLE "public"."couples" TO "anon";
GRANT ALL ON TABLE "public"."couples" TO "authenticated";
GRANT ALL ON TABLE "public"."couples" TO "service_role";



GRANT ALL ON TABLE "public"."daily_questions" TO "anon";
GRANT ALL ON TABLE "public"."daily_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_questions" TO "service_role";



GRANT ALL ON TABLE "public"."gift_reminders" TO "anon";
GRANT ALL ON TABLE "public"."gift_reminders" TO "authenticated";
GRANT ALL ON TABLE "public"."gift_reminders" TO "service_role";



GRANT ALL ON TABLE "public"."license_details" TO "anon";
GRANT ALL ON TABLE "public"."license_details" TO "authenticated";
GRANT ALL ON TABLE "public"."license_details" TO "service_role";



GRANT ALL ON TABLE "public"."love_notes" TO "anon";
GRANT ALL ON TABLE "public"."love_notes" TO "authenticated";
GRANT ALL ON TABLE "public"."love_notes" TO "service_role";



GRANT ALL ON TABLE "public"."moods" TO "anon";
GRANT ALL ON TABLE "public"."moods" TO "authenticated";
GRANT ALL ON TABLE "public"."moods" TO "service_role";



GRANT ALL ON TABLE "public"."pairing_codes" TO "anon";
GRANT ALL ON TABLE "public"."pairing_codes" TO "authenticated";
GRANT ALL ON TABLE "public"."pairing_codes" TO "service_role";



GRANT ALL ON TABLE "public"."time_capsules" TO "anon";
GRANT ALL ON TABLE "public"."time_capsules" TO "authenticated";
GRANT ALL ON TABLE "public"."time_capsules" TO "service_role";



GRANT ALL ON TABLE "public"."timeline_items" TO "anon";
GRANT ALL ON TABLE "public"."timeline_items" TO "authenticated";
GRANT ALL ON TABLE "public"."timeline_items" TO "service_role";



GRANT ALL ON TABLE "public"."topic_cards" TO "anon";
GRANT ALL ON TABLE "public"."topic_cards" TO "authenticated";
GRANT ALL ON TABLE "public"."topic_cards" TO "service_role";



GRANT ALL ON TABLE "public"."user_fcm_tokens" TO "anon";
GRANT ALL ON TABLE "public"."user_fcm_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."user_fcm_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."vault_items" TO "anon";
GRANT ALL ON TABLE "public"."vault_items" TO "authenticated";
GRANT ALL ON TABLE "public"."vault_items" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";

































-- FILE: 20260630000000_secure_rls_policies.sql
-- Migration: Secure RLS Policies and Implement Join Couple RPC
-- Created: 2026-06-30

-- 1. DROP INSECURE POLICIES
DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.pairing_codes;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.pairing_codes;
DROP POLICY IF EXISTS "Enable update for own profile or pairing partner" ON public.users;

-- 2. CREATE SECURE POLICIES FOR pairing_codes
-- Allow creators to select/read their own pairing codes
CREATE POLICY "Enable select for creator" ON public.pairing_codes
  FOR SELECT TO authenticated
  USING (auth.uid() = creator_id);

-- Allow creators to delete/cancel their own pairing codes
CREATE POLICY "Enable delete for creator" ON public.pairing_codes
  FOR DELETE TO authenticated
  USING (auth.uid() = creator_id);

-- 3. CREATE SECURE POLICIES FOR users
-- Restrict updates strictly to the user's own profile
CREATE POLICY "Enable update for own profile" ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 4. CREATE HIGH-PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS pairing_codes_code_idx ON public.pairing_codes (code);
CREATE INDEX IF NOT EXISTS pairing_codes_creator_id_idx ON public.pairing_codes (creator_id);

-- 5. ATOMIC JOIN COUPLE RPC FUNCTION
CREATE OR REPLACE FUNCTION public.join_couple_with_code(pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with elevated privileges to update creator profile and delete code
AS $$
DECLARE
  v_creator_id uuid;
  v_creator_couple_id uuid;
  v_joiner_id uuid;
  v_created_at timestamptz;
BEGIN
  -- Get active transaction user ID (joiner)
  v_joiner_id := auth.uid();
  IF v_joiner_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Retrieve and lock pairing code row to prevent race conditions
  SELECT creator_id, created_at
  INTO v_creator_id, v_created_at
  FROM public.pairing_codes
  WHERE code = upper(trim(pairing_code))
  FOR UPDATE; -- Row-level lock

  IF v_creator_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid pairing code');
  END IF;

  -- Prevent self-pairing
  IF v_creator_id = v_joiner_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot pair with yourself');
  END IF;

  -- Enforce 24-hour expiration on pairing codes
  IF v_created_at < now() - interval '24 hours' THEN
    DELETE FROM public.pairing_codes WHERE code = upper(trim(pairing_code));
    RETURN json_build_object('success', false, 'error', 'Pairing code has expired');
  END IF;

  -- Fetch the creator's couple_id
  SELECT couple_id
  INTO v_creator_couple_id
  FROM public.users
  WHERE id = v_creator_id;

  -- If creator doesn't have a couple_id yet, generate and assign one
  IF v_creator_couple_id IS NULL THEN
    v_creator_couple_id := gen_random_uuid();
    INSERT INTO public.couples (id, story_title)
    VALUES (v_creator_couple_id, 'Our Story');

    UPDATE public.users
    SET couple_id = v_creator_couple_id
    WHERE id = v_creator_id;
  END IF;

  -- Transaction: link both users
  UPDATE public.users
  SET partner_id = v_joiner_id, couple_id = v_creator_couple_id
  WHERE id = v_creator_id;

  UPDATE public.users
  SET partner_id = v_creator_id, couple_id = v_creator_couple_id
  WHERE id = v_joiner_id;

  -- Delete the used code
  DELETE FROM public.pairing_codes WHERE code = upper(trim(pairing_code));

  RETURN json_build_object(
    'success', true,
    'couple_id', v_creator_couple_id,
    'partner_id', v_creator_id
  );
END;
$$;


-- FILE: 20260630000001_topic_card_likes.sql
-- Migration: Create topic_card_likes table and configure secure RLS policies
-- Created: 2026-06-30

CREATE TABLE IF NOT EXISTS public.topic_card_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id uuid NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  card_id text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (couple_id, user_id, card_id)
);

-- Enable RLS
ALTER TABLE public.topic_card_likes ENABLE ROW LEVEL SECURITY;

-- Policy: Select likes for the couple
CREATE POLICY "Enable select for same couple" ON public.topic_card_likes
  FOR SELECT TO authenticated
  USING (
    couple_id IN (
      SELECT couple_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Policy: Insert own likes
CREATE POLICY "Enable insert for own user" ON public.topic_card_likes
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid() AND
    couple_id IN (
      SELECT couple_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Policy: Delete own likes
CREATE POLICY "Enable delete for own user" ON public.topic_card_likes
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
  );

-- Indexes
CREATE INDEX IF NOT EXISTS topic_card_likes_couple_id_idx ON public.topic_card_likes (couple_id);
CREATE INDEX IF NOT EXISTS topic_card_likes_user_id_idx ON public.topic_card_likes (user_id);
CREATE INDEX IF NOT EXISTS topic_card_likes_card_id_idx ON public.topic_card_likes (card_id);


-- FILE: 20260630000002_pairing_flow_hardening.sql
-- Migration: Harden pairing flow, enforce unique active code per creator, and validate relationship statuses
-- Created: 2026-06-30

-- 1. ENFORCE ONE ACTIVE CODE PER USER
-- Try to drop existing constraint if it exists
ALTER TABLE public.pairing_codes DROP CONSTRAINT IF EXISTS pairing_codes_creator_id_key;
ALTER TABLE public.pairing_codes ADD CONSTRAINT pairing_codes_creator_id_key UNIQUE (creator_id);

-- 2. HARDEN JOIN RELATIONSHIP RPC
CREATE OR REPLACE FUNCTION public.join_couple_with_code(pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_creator_id uuid;
  v_creator_couple_id uuid;
  v_joiner_id uuid;
  v_created_at timestamptz;
BEGIN
  -- Get active transaction user ID (joiner)
  v_joiner_id := auth.uid();
  IF v_joiner_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Retrieve and lock pairing code row to prevent race conditions (FOR UPDATE)
  SELECT creator_id, created_at
  INTO v_creator_id, v_created_at
  FROM public.pairing_codes
  WHERE code = upper(trim(pairing_code))
  FOR UPDATE;

  IF v_creator_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid pairing code');
  END IF;

  -- Prevent self-pairing
  IF v_creator_id = v_joiner_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot pair with yourself');
  END IF;

  -- Enforce 24-hour expiration on pairing codes
  IF v_created_at < now() - interval '24 hours' THEN
    DELETE FROM public.pairing_codes WHERE code = upper(trim(pairing_code));
    RETURN json_build_object('success', false, 'error', 'Pairing code has expired');
  END IF;

  -- Check if joiner is already paired (to prevent hijacking/breaking existing relationship)
  IF EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = v_joiner_id AND partner_id IS NOT NULL
  ) THEN
    RETURN json_build_object('success', false, 'error', 'You are already paired in a relationship');
  END IF;

  -- Check if creator is already paired
  IF EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = v_creator_id AND partner_id IS NOT NULL
  ) THEN
    RETURN json_build_object('success', false, 'error', 'The creator of this code is already paired');
  END IF;

  -- Fetch the creator's couple_id
  SELECT couple_id
  INTO v_creator_couple_id
  FROM public.users
  WHERE id = v_creator_id;

  -- If creator doesn't have a couple_id yet, generate and assign one
  IF v_creator_couple_id IS NULL THEN
    v_creator_couple_id := gen_random_uuid();
    INSERT INTO public.couples (id, story_title)
    VALUES (v_creator_couple_id, 'Our Story');

    UPDATE public.users
    SET couple_id = v_creator_couple_id
    WHERE id = v_creator_id;
  END IF;

  -- Transaction: link both users
  UPDATE public.users
  SET partner_id = v_joiner_id, couple_id = v_creator_couple_id
  WHERE id = v_creator_id;

  UPDATE public.users
  SET partner_id = v_creator_id, couple_id = v_creator_couple_id
  WHERE id = v_joiner_id;

  -- Delete the used code
  DELETE FROM public.pairing_codes WHERE code = upper(trim(pairing_code));

  RETURN json_build_object(
    'success', true,
    'couple_id', v_creator_couple_id,
    'partner_id', v_creator_id
  );
END;
$$;


-- FILE: 20260630000003_account_deletion_cleanup.sql
-- Migration: Implement Safe, Atomic Account Deletion & Relationship Cleanup
-- Created: 2026-06-30

-- 1. ADD NOTICE COLUMN FOR REMAINING PARTNER
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS partner_deleted_notice boolean DEFAULT false;

-- 2. CREATE USER DELETION TRIGGER CLEANUP FUNCTION
CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  -- Capture the partner_id and couple_id of the user being deleted
  v_partner_id := OLD.partner_id;
  v_couple_id := OLD.couple_id;

  -- A. Clean up remaining partner (if any)
  IF v_partner_id IS NOT NULL THEN
    UPDATE public.users
    SET 
      partner_id = NULL,
      couple_id = NULL,
      partner_deleted_notice = TRUE
    WHERE id = v_partner_id;
  END IF;

  -- B. Clean up the couple record and cascade delete shared resources
  IF v_couple_id IS NOT NULL THEN
    -- Only delete the couple if no other active user is associated with it
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on public.users
DROP TRIGGER IF EXISTS user_deletion_cleanup_trg ON public.users;
CREATE TRIGGER user_deletion_cleanup_trg
  BEFORE DELETE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_deletion_cleanup();

-- 3. CREATE SECURE RPC TO DELETE AUTH USER
CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Deleting from auth.users will cascade to public.users and trigger cleanup
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN json_build_object('success', true);
END;
$$;


-- FILE: 20260702000000_user_notification_preferences.sql
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


-- FILE: 20260702000001_relationship_activities.sql
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



-- FILE: 20260702000002_users_created_at.sql
-- Migration: Add created_at column to public.users table
-- Needed for partner join date display
-- Created: 2026-07-02

-- 1. Add the column (nullable, with default for new rows)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- 2. Backfill existing rows from auth.users
UPDATE public.users u
SET created_at = a.created_at
FROM auth.users a
WHERE u.id = a.id
  AND u.created_at IS NULL;

-- 3. Also add a name column if missing (used by activity triggers)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS name text;


-- FILE: 20260702000003_create_storage_buckets.sql
-- Migration: Create Storage Buckets and Policies
-- Created: 2026-07-02

-- 1. Create the storage buckets if they do not exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('love-notes', 'love-notes', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif']),
  ('timeline', 'timeline', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif']),
  ('vault-photos', 'vault-photos', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- 2. Drop existing policies if they exist to avoid collisions
DROP POLICY IF EXISTS "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from love-notes, timeline, vault" ON storage.objects;

-- 3. Create RLS policies for storage objects in our buckets
CREATE POLICY "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
  );

CREATE POLICY "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
  );

CREATE POLICY "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
  );

CREATE POLICY "Allow public read from love-notes, timeline, vault" ON storage.objects
  FOR SELECT TO public
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
  );


-- FILE: 20260702000004_create_avatars_bucket.sql
-- Migration: Create Avatars Storage Bucket and Policies
-- Created: 2026-07-02

-- 1. Create the avatars storage bucket if it does not exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('avatars', 'avatars', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- 2. Drop existing policies if they exist to avoid collisions
DROP POLICY IF EXISTS "Allow authenticated uploads to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from avatars" ON storage.objects;

-- 3. Create RLS policies for storage objects in avatars bucket
CREATE POLICY "Allow authenticated uploads to avatars" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
  );

CREATE POLICY "Allow authenticated updates to avatars" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
  );

CREATE POLICY "Allow authenticated deletes from avatars" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
  );

CREATE POLICY "Allow public read from avatars" ON storage.objects
  FOR SELECT TO public
  USING (
    bucket_id = 'avatars'
  );


-- FILE: 20260702000005_drop_relationship_activities.sql
-- Migration: Drop Relationship Activities Table and Triggers
-- Created: 2026-07-02

-- 1. Drop triggers on other tables
DROP TRIGGER IF EXISTS on_love_notes_inserted ON public.love_notes;
DROP TRIGGER IF EXISTS on_bucket_list_modified ON public.bucket_list;
DROP TRIGGER IF EXISTS on_calendar_events_modified ON public.calendar_events;
DROP TRIGGER IF EXISTS on_time_capsules_modified ON public.time_capsules;
DROP TRIGGER IF EXISTS on_vault_items_modified ON public.vault_items;
DROP TRIGGER IF EXISTS on_topic_cards_modified ON public.topic_cards;
DROP TRIGGER IF EXISTS on_topic_card_likes_inserted ON public.topic_card_likes;
DROP TRIGGER IF EXISTS on_gift_reminders_modified ON public.gift_reminders;
DROP TRIGGER IF EXISTS on_moods_modified ON public.moods;
DROP TRIGGER IF EXISTS on_timeline_items_modified ON public.timeline_items;

-- 2. Drop trigger functions
DROP FUNCTION IF EXISTS public.log_love_notes_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_bucket_list_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_calendar_events_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_time_capsules_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_vault_items_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_topic_cards_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_topic_card_likes_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_gift_reminders_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_moods_activity() CASCADE;
DROP FUNCTION IF EXISTS public.log_timeline_items_activity() CASCADE;

-- 3. Drop the relationship activities table
DROP TABLE IF EXISTS public.relationship_activities CASCADE;


-- FILE: 20260705000000_create_love_taps.sql
-- Migration: Create Love Taps table and add current_activity to users
-- Created: 2026-07-05

-- 1. Add current_activity column to public.users table if it doesn't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS current_activity text;

-- 2. Create love_taps table
CREATE TABLE IF NOT EXISTS public.love_taps (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    couple_id uuid NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    date date NOT NULL,
    partner1_tapped boolean DEFAULT false NOT NULL,
    partner2_tapped boolean DEFAULT false NOT NULL,
    partner1_timestamp timestamptz,
    partner2_timestamp timestamptz,
    completed_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    UNIQUE (couple_id, date)
);

-- 3. Enable Row Level Security
ALTER TABLE public.love_taps ENABLE ROW LEVEL SECURITY;

-- 4. Policies for RLS
DROP POLICY IF EXISTS "Enable select for same couple" ON public.love_taps;
CREATE POLICY "Enable select for same couple" ON public.love_taps
  FOR SELECT TO authenticated
  USING (couple_id IN (SELECT couple_id FROM public.users WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Enable insert for same couple" ON public.love_taps;
CREATE POLICY "Enable insert for same couple" ON public.love_taps
  FOR INSERT TO authenticated
  WITH CHECK (couple_id IN (SELECT couple_id FROM public.users WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Enable update for same couple" ON public.love_taps;
CREATE POLICY "Enable update for same couple" ON public.love_taps
  FOR UPDATE TO authenticated
  USING (couple_id IN (SELECT couple_id FROM public.users WHERE id = auth.uid()))
  WITH CHECK (couple_id IN (SELECT couple_id FROM public.users WHERE id = auth.uid()));

-- 5. Create performance index
CREATE INDEX IF NOT EXISTS love_taps_couple_id_date_idx ON public.love_taps (couple_id, date);

-- 6. Add to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.love_taps;


-- FILE: 20260706000000_persistent_relationship_workspace.sql
-- Migration: Implement Persistent Relationship Workspace Schema and secure transaction-safe RPCs
-- Created: 2026-07-06

-- Enable pgcrypto if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Create failed_recovery_attempts table for rate limiting/cooldown
CREATE TABLE IF NOT EXISTS public.failed_recovery_attempts (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  attempts integer DEFAULT 0 NOT NULL,
  locked_until timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS on rate limit table
ALTER TABLE public.failed_recovery_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable select/update for own attempts" ON public.failed_recovery_attempts;
CREATE POLICY "Enable select/update for own attempts" ON public.failed_recovery_attempts
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Alter couples table to support workspace state
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS status text DEFAULT 'waiting' NOT NULL;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_a_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_b_id uuid REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS pairing_code character varying(6) UNIQUE;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_lookup_key text UNIQUE;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_code_hash text;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS couples_recovery_lookup_key_idx ON public.couples (recovery_lookup_key);

-- 3. Populate existing couples from users table
DO $$
DECLARE
  r record;
  v_partner_a uuid;
  v_partner_b uuid;
BEGIN
  FOR r IN SELECT DISTINCT couple_id FROM public.users WHERE couple_id IS NOT NULL LOOP
    SELECT id INTO v_partner_a FROM public.users WHERE couple_id = r.couple_id ORDER BY id ASC LIMIT 1;
    SELECT id INTO v_partner_b FROM public.users WHERE couple_id = r.couple_id ORDER BY id ASC LIMIT 1 OFFSET 1;

    UPDATE public.couples
    SET 
      partner_a_id = v_partner_a,
      partner_b_id = v_partner_b,
      status = CASE WHEN v_partner_b IS NOT NULL THEN 'active' ELSE 'waiting' END
    WHERE id = r.couple_id;
  END LOOP;
END;
$$;

-- 4. Clean up users table
ALTER TABLE public.users DROP COLUMN IF EXISTS partner_id;

-- 5. Drop old pairing_codes table
DROP TABLE IF EXISTS public.pairing_codes CASCADE;

-- 6. Redefine is_member_of_couple to verify workspace and active status
CREATE OR REPLACE FUNCTION public.is_member_of_couple(couple_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.couples c ON c.id = u.couple_id
    WHERE u.id = auth.uid()
      AND u.couple_id = is_member_of_couple.couple_id
      AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
      AND c.status != 'archived'
  );
END;
$$;

-- 7. Trigger function to automatically update updated_at on couples
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_couples_updated_at ON public.couples;
CREATE TRIGGER update_couples_updated_at
  BEFORE UPDATE ON public.couples
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- 8. Define create_relationship_workspace RPC
CREATE OR REPLACE FUNCTION public.create_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_couple_id uuid;
  v_pairing_code text;
  v_lookup_key text;
  v_secret_formatted text;
  v_secret_clean text;
  v_user_couple_id uuid;
  v_code_exists boolean;
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  -- Lock caller row to prevent concurrent updates
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();
  
  -- Retry loop to generate unique codes
  LOOP
    v_pairing_code := '';
    FOR i IN 1..6 LOOP
      v_pairing_code := v_pairing_code || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS(SELECT 1 FROM public.couples WHERE pairing_code = v_pairing_code) INTO v_code_exists;
    SELECT EXISTS(SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;
    
    IF NOT v_code_exists AND NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  -- Generate 16-char secret key grouped with hyphens
  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  -- Insert couple row with Blowfish hash of the clean secret
  INSERT INTO public.couples (id, status, partner_a_id, pairing_code, recovery_lookup_key, recovery_code_hash)
  VALUES (
    v_couple_id,
    'waiting',
    auth.uid(),
    v_pairing_code,
    v_lookup_key,
    crypt(v_secret_clean, gen_salt('bf', 10))
  );

  -- Update user couple_id
  UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- 9. Define join_relationship_with_code RPC
CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_couple_row public.couples%ROWTYPE;
  v_user_couple_id uuid;
BEGIN
  -- Lock caller row to prevent race conditions
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- Find and lock couples row
  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE upper(pairing_code) = upper(trim(p_pairing_code))
    AND status = 'waiting'
    AND partner_b_id IS NULL
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired pairing code';
  END IF;

  IF v_couple_row.partner_a_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot pair with yourself';
  END IF;

  -- Update couple record
  UPDATE public.couples
  SET 
    partner_b_id = auth.uid(),
    status = 'active',
    pairing_code = NULL
  WHERE id = v_couple_row.id;

  -- Update user record
  UPDATE public.users
  SET couple_id = v_couple_row.id
  WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_row.id,
    'partner_id', v_couple_row.partner_a_id
  );
END;
$$;

-- 10. Define recover_relationship_with_code RPC
CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_id uuid;
  v_couple_row record;
  v_attempts integer;
  v_locked_until timestamp with time zone;
  v_user_couple_id uuid;
  v_success boolean := false;
BEGIN
  -- Lock user row to prevent race conditions
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- Check rate limiting
  SELECT attempts, locked_until INTO v_attempts, v_locked_until
  FROM public.failed_recovery_attempts
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
  END IF;

  -- Clean and parse code (case-insensitive & whitespace tolerant)
  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(replace(v_secret, '-', ''), ' ', '');

    -- Query couples using index on lookup key and lock it
    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      -- Verify BCrypt hash
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        -- Validate ownership: either they are already in the couple, or one of the slots is empty (which they can claim)
        IF v_couple_row.partner_a_id = auth.uid() OR v_couple_row.partner_b_id = auth.uid() OR v_couple_row.partner_a_id IS NULL OR v_couple_row.partner_b_id IS NULL THEN
          v_success := true;
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_success THEN
    -- Assign caller to the correct partner slot in couples if not already set
    IF v_couple_row.partner_a_id IS NULL AND (v_couple_row.partner_b_id IS NULL OR v_couple_row.partner_b_id != auth.uid()) THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    ELSIF v_couple_row.partner_b_id IS NULL AND (v_couple_row.partner_a_id IS NULL OR v_couple_row.partner_a_id != auth.uid()) THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    ELSE
      UPDATE public.couples SET status = 'active' WHERE id = v_couple_row.id;
    END IF;

    -- Success: Reset attempts, connect user
    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 0, NULL)
    ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

    UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

    RETURN json_build_object(
      'success', true,
      'couple_id', v_couple_row.id
    );
  ELSE
    -- Failed attempt: log failed attempt and raise exception
    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      attempts = failed_recovery_attempts.attempts + 1,
      locked_until = CASE WHEN failed_recovery_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
      updated_at = now();
      
    RAISE EXCEPTION 'Invalid recovery code';
  END IF;
END;
$$;

-- 11. Define regenerate_recovery_code RPC
CREATE OR REPLACE FUNCTION public.regenerate_recovery_code()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_couple_id uuid;
  v_lookup_key text;
  v_secret_clean text;
  v_secret_formatted text;
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  -- Lock user row
  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RAISE EXCEPTION 'Not in a relationship';
  END IF;

  -- Lock couples row
  IF NOT EXISTS (
    SELECT 1 FROM public.couples WHERE id = v_couple_id AND (partner_a_id = auth.uid() OR partner_b_id = auth.uid()) FOR UPDATE
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Generate lookup key in retry loop
  LOOP
    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS (SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;
    IF NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  -- Generate 16-char secret key
  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  UPDATE public.couples
  SET 
    recovery_lookup_key = v_lookup_key,
    recovery_code_hash = crypt(v_secret_clean, gen_salt('bf', 10))
  WHERE id = v_couple_id;

  RETURN json_build_object(
    'success', true,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- 12. Define disconnect_relationship_workspace RPC
CREATE OR REPLACE FUNCTION public.disconnect_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_couple_id uuid;
  v_other_connected boolean;
BEGIN
  -- Lock caller user row
  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not in a relationship');
  END IF;

  -- Lock couple row
  PERFORM 1 FROM public.couples WHERE id = v_couple_id FOR UPDATE;

  -- Update user to null
  UPDATE public.users SET couple_id = NULL WHERE id = auth.uid();

  -- Clear corresponding partner_id slot in couples table
  UPDATE public.couples
  SET 
    partner_a_id = CASE WHEN partner_a_id = auth.uid() THEN NULL ELSE partner_a_id END,
    partner_b_id = CASE WHEN partner_b_id = auth.uid() THEN NULL ELSE partner_b_id END
  WHERE id = v_couple_id;

  -- Check if other partner is still connected
  SELECT EXISTS (
    SELECT 1 FROM public.users 
    WHERE couple_id = v_couple_id AND id != auth.uid()
  ) INTO v_other_connected;

  IF NOT v_other_connected THEN
    UPDATE public.couples SET status = 'disconnected' WHERE id = v_couple_id;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;


-- FILE: 20260707000000_fix_love_notes_deletion_cascade.sql
-- Migration: Add ON DELETE CASCADE to love_notes_sender_id_fkey
-- Created: 2026-07-07

ALTER TABLE public.love_notes
DROP CONSTRAINT IF EXISTS love_notes_sender_id_fkey;

ALTER TABLE public.love_notes
ADD CONSTRAINT love_notes_sender_id_fkey
FOREIGN KEY (sender_id)
REFERENCES auth.users(id)
ON DELETE CASCADE;


-- FILE: 20260707000001_security_hardening.sql
-- Migration: Security Hardening - Search Path, Rate Limiting, and RLS Isolation
-- Created: 2026-07-07

-- 1. ADD PAIRING CODE RATE LIMITING
CREATE TABLE IF NOT EXISTS public.failed_pairing_attempts (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  attempts integer DEFAULT 0 NOT NULL,
  locked_until timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.failed_pairing_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable select/update for own pairing attempts" ON public.failed_pairing_attempts;
CREATE POLICY "Enable select/update for own pairing attempts" ON public.failed_pairing_attempts
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. HARDEN SECURITY DEFINER FUNCTIONS (SET search_path)
-- This prevents search path hijacking attacks.

-- get_user_couple_id
CREATE OR REPLACE FUNCTION public.get_user_couple_id(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT couple_id::text FROM public.users WHERE id = user_id;
$$;

-- is_member_of_couple
CREATE OR REPLACE FUNCTION public.is_member_of_couple(couple_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.couples c ON c.id = u.couple_id
    WHERE u.id = auth.uid()
      AND u.couple_id = is_member_of_couple.couple_id
      AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
      AND c.status != 'archived'
  );
END;
$$;

-- handle_user_deletion_cleanup
CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  v_partner_id := OLD.partner_id;
  v_couple_id := OLD.couple_id;

  IF v_partner_id IS NOT NULL THEN
    UPDATE public.users
    SET
      partner_id = NULL,
      couple_id = NULL,
      partner_deleted_notice = TRUE
    WHERE id = v_partner_id;
  END IF;

  IF v_couple_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$;

-- delete_current_user
CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN json_build_object('success', true);
END;
$$;

-- create_relationship_workspace
CREATE OR REPLACE FUNCTION public.create_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_couple_id uuid;
  v_pairing_code text;
  v_lookup_key text;
  v_secret_formatted text;
  v_secret_clean text;
  v_user_couple_id uuid;
  v_code_exists boolean;
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();

  LOOP
    v_pairing_code := '';
    FOR i IN 1..6 LOOP
      v_pairing_code := v_pairing_code || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS(SELECT 1 FROM public.couples WHERE pairing_code = v_pairing_code) INTO v_code_exists;
    SELECT EXISTS(SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;

    IF NOT v_code_exists AND NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  INSERT INTO public.couples (id, status, partner_a_id, pairing_code, recovery_lookup_key, recovery_code_hash)
  VALUES (
    v_couple_id,
    'waiting',
    auth.uid(),
    v_pairing_code,
    v_lookup_key,
    crypt(v_secret_clean, gen_salt('bf', 10))
  );

  UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- join_relationship_with_code (Updated with rate limiting)
CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_row public.couples%ROWTYPE;
  v_user_couple_id uuid;
  v_attempts integer;
  v_locked_until timestamp with time zone;
BEGIN
  -- 1. Check rate limiting
  SELECT attempts, locked_until INTO v_attempts, v_locked_until
  FROM public.failed_pairing_attempts
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
  END IF;

  -- 2. Lock caller row
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- 3. Find and lock couples row
  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE upper(pairing_code) = upper(trim(p_pairing_code))
    AND status = 'waiting'
    AND partner_b_id IS NULL
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    -- Log failed attempt
    INSERT INTO public.failed_pairing_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      attempts = failed_pairing_attempts.attempts + 1,
      locked_until = CASE WHEN failed_pairing_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
      updated_at = now();

    RAISE EXCEPTION 'Invalid or expired pairing code';
  END IF;

  IF v_couple_row.partner_a_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot pair with yourself';
  END IF;

  -- 4. Success: Reset attempts and update records
  INSERT INTO public.failed_pairing_attempts (user_id, attempts, locked_until)
  VALUES (auth.uid(), 0, NULL)
  ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

  UPDATE public.couples
  SET
    partner_b_id = auth.uid(),
    status = 'active',
    pairing_code = NULL
  WHERE id = v_couple_row.id;

  UPDATE public.users
  SET couple_id = v_couple_row.id
  WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_row.id,
    'partner_id', v_couple_row.partner_a_id
  );
END;
$$;

-- recover_relationship_with_code
CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_id uuid;
  v_couple_row record;
  v_attempts integer;
  v_locked_until timestamp with time zone;
  v_user_couple_id uuid;
  v_success boolean := false;
BEGIN
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  SELECT attempts, locked_until INTO v_attempts, v_locked_until
  FROM public.failed_recovery_attempts
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
  END IF;

  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(replace(v_secret, '-', ''), ' ', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        IF v_couple_row.partner_a_id = auth.uid() OR v_couple_row.partner_b_id = auth.uid() OR v_couple_row.partner_a_id IS NULL OR v_couple_row.partner_b_id IS NULL THEN
          v_success := true;
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_success THEN
    IF v_couple_row.partner_a_id IS NULL AND (v_couple_row.partner_b_id IS NULL OR v_couple_row.partner_b_id != auth.uid()) THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    ELSIF v_couple_row.partner_b_id IS NULL AND (v_couple_row.partner_a_id IS NULL OR v_couple_row.partner_a_id != auth.uid()) THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    ELSE
      UPDATE public.couples SET status = 'active' WHERE id = v_couple_row.id;
    END IF;

    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 0, NULL)
    ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

    UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

    RETURN json_build_object(
      'success', true,
      'couple_id', v_couple_row.id
    );
  ELSE
    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      attempts = failed_recovery_attempts.attempts + 1,
      locked_until = CASE WHEN failed_recovery_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
      updated_at = now();

    RAISE EXCEPTION 'Invalid recovery code';
  END IF;
END;
$$;

-- regenerate_recovery_code
CREATE OR REPLACE FUNCTION public.regenerate_recovery_code()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_couple_id uuid;
  v_lookup_key text;
  v_secret_clean text;
  v_secret_formatted text;
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RAISE EXCEPTION 'Not in a relationship';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.couples WHERE id = v_couple_id AND (partner_a_id = auth.uid() OR partner_b_id = auth.uid()) FOR UPDATE
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  LOOP
    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS (SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;
    IF NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  UPDATE public.couples
  SET
    recovery_lookup_key = v_lookup_key,
    recovery_code_hash = crypt(v_secret_clean, gen_salt('bf', 10))
  WHERE id = v_couple_id;

  RETURN json_build_object(
    'success', true,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- disconnect_relationship_workspace
CREATE OR REPLACE FUNCTION public.disconnect_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_id uuid;
  v_other_connected boolean;
BEGIN
  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not in a relationship');
  END IF;

  PERFORM 1 FROM public.couples WHERE id = v_couple_id FOR UPDATE;

  UPDATE public.users SET couple_id = NULL WHERE id = auth.uid();

  UPDATE public.couples
  SET
    partner_a_id = CASE WHEN partner_a_id = auth.uid() THEN NULL ELSE partner_a_id END,
    partner_b_id = CASE WHEN partner_b_id = auth.uid() THEN NULL ELSE partner_b_id END
  WHERE id = v_couple_id;

  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE couple_id = v_couple_id AND id != auth.uid()
  ) INTO v_other_connected;

  IF NOT v_other_connected THEN
    UPDATE public.couples SET status = 'disconnected' WHERE id = v_couple_id;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- handle_new_user_notification_preferences
CREATE OR REPLACE FUNCTION public.handle_new_user_notification_preferences()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_notification_preferences (user_id)
    VALUES (new.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN new;
END;
$$;

-- 3. TIGHTEN RLS POLICIES

-- public.users: Restrict SELECT to self and partner only
-- Fixed to avoid infinite recursion by using auth.jwt() to check couple_id
DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.users;
DROP POLICY IF EXISTS "Enable select for self and partner" ON public.users;
CREATE POLICY "Enable select for self and partner" ON public.users
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR
    (couple_id IS NOT NULL AND couple_id = (NULLIF(current_setting('request.jwt.claims', true)::json->>'couple_id', '')::uuid))
  );

-- public.couples: Restrict SELECT/UPDATE to members
DROP POLICY IF EXISTS "Enable select for couple members" ON public.couples;
DROP POLICY IF EXISTS "Enable select for members" ON public.couples;
CREATE POLICY "Enable select for members" ON public.couples
  FOR SELECT TO authenticated
  USING (partner_a_id = auth.uid() OR partner_b_id = auth.uid());

DROP POLICY IF EXISTS "Enable update for couple members" ON public.couples;
DROP POLICY IF EXISTS "Enable update for members" ON public.couples;
CREATE POLICY "Enable update for members" ON public.couples
  FOR UPDATE TO authenticated
  USING (partner_a_id = auth.uid() OR partner_b_id = auth.uid())
  WITH CHECK (partner_a_id = auth.uid() OR partner_b_id = auth.uid());

-- Ensure other tables have strictly scoped policies
-- All feature tables (love_notes, timeline_items, etc.) use is_member_of_couple(couple_id).
-- Since we hardened is_member_of_couple above, those tables are now more secure.


-- FILE: 20260707000002_database_optimizations.sql
-- Migration: Database Optimizations - Performance Indexes & Integrity Constraints
-- Created: 2026-07-07

-- 1. ADD PERFORMANCE INDEXES FOR SHARED FEATURES
-- These indexes prevent full table scans when querying relationship data.
CREATE INDEX IF NOT EXISTS idx_timeline_items_couple_id ON public.timeline_items (couple_id);
CREATE INDEX IF NOT EXISTS idx_love_notes_couple_id ON public.love_notes (couple_id);
CREATE INDEX IF NOT EXISTS idx_bucket_list_couple_id ON public.bucket_list (couple_id);
CREATE INDEX IF NOT EXISTS idx_moods_couple_id ON public.moods (couple_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_couple_id ON public.calendar_events (couple_id);
CREATE INDEX IF NOT EXISTS idx_vault_items_couple_id ON public.vault_items (couple_id);
CREATE INDEX IF NOT EXISTS idx_gift_reminders_couple_id ON public.gift_reminders (couple_id);
CREATE INDEX IF NOT EXISTS idx_time_capsules_couple_id ON public.time_capsules (couple_id);

-- 2. ENFORCE UNIQUENESS ON WORKSPACE IDENTIFIERS
-- This adds a second layer of protection alongside the application logic.
ALTER TABLE public.couples DROP CONSTRAINT IF EXISTS couples_pairing_code_unique;
ALTER TABLE public.couples ADD CONSTRAINT couples_pairing_code_unique UNIQUE (pairing_code);

ALTER TABLE public.couples DROP CONSTRAINT IF EXISTS couples_recovery_lookup_key_unique;
ALTER TABLE public.couples ADD CONSTRAINT couples_recovery_lookup_key_unique UNIQUE (recovery_lookup_key);

-- 3. STORAGE CLEANUP TRACKING (Optional/Future Proofing)
-- Create a table to track files that need to be deleted from storage.
-- This allows moving cleanup logic to the server via webhooks or edge functions.
CREATE TABLE IF NOT EXISTS public.storage_cleanup_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_name text NOT NULL,
  storage_path text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.storage_cleanup_queue ENABLE ROW LEVEL SECURITY;
-- No public policies needed as this is system-managed.


-- FILE: 20260711000000_audit_fixes.sql
-- Migration: Database Integrity & Security Hardening Fixes
-- Created: 2026-07-11
--
-- ROLLBACK STEPS:
-- To revert these changes, run the following SQL statements:
--
-- 1. Revert user deletion trigger function to use OLD.partner_id:
--    CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
--    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
--    DECLARE v_partner_id uuid; v_couple_id uuid; BEGIN
--    v_partner_id := OLD.partner_id; v_couple_id := OLD.couple_id;
--    IF v_partner_id IS NOT NULL THEN
--      UPDATE public.users SET partner_id = NULL, couple_id = NULL, partner_deleted_notice = TRUE WHERE id = v_partner_id;
--    END IF;
--    IF v_couple_id IS NOT NULL THEN
--      IF NOT EXISTS (SELECT 1 FROM public.users WHERE couple_id = v_couple_id AND id != OLD.id) THEN
--        DELETE FROM public.couples WHERE id = v_couple_id;
--      END IF;
--    END IF;
--    RETURN OLD;
--    END; $$;
--
-- 2. Revert users SELECT RLS policy back to JWT claims:
--    DROP POLICY IF EXISTS "Enable select for self and partner" ON public.users;
--    CREATE POLICY "Enable select for self and partner" ON public.users FOR SELECT TO authenticated
--      USING (id = auth.uid() OR (couple_id IS NOT NULL AND couple_id = (NULLIF(current_setting('request.jwt.claims', true)::json->>'couple_id', '')::uuid)));
--
-- 3. Revert is_premium protection:
--    DROP TRIGGER IF EXISTS trg_protect_premium_status ON public.couples;
--    DROP FUNCTION IF EXISTS public.protect_premium_status();
--
-- 4. Revert foreign keys to ON DELETE CASCADE:
--    ALTER TABLE public.love_notes DROP CONSTRAINT IF EXISTS love_notes_sender_id_fkey;
--    ALTER TABLE public.love_notes ADD CONSTRAINT love_notes_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;
--    ALTER TABLE public.moods DROP CONSTRAINT IF EXISTS moods_user_id_fkey;
--    ALTER TABLE public.moods ADD CONSTRAINT moods_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
--
-- 5. Revert security guards from RPCs by removing "IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;" checks.
--

-- =====================================================================
-- 1. REFACTOR USER DELETION TRIGGER FUNCTION (LOOKUP VIA COUPLES TABLE)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  v_couple_id := OLD.couple_id;

  IF v_couple_id IS NOT NULL THEN
    -- Look up partner ID from couples table (partner_id column is dropped on users)
    SELECT 
      CASE WHEN partner_a_id = OLD.id THEN partner_b_id ELSE partner_a_id END
    INTO v_partner_id
    FROM public.couples
    WHERE id = v_couple_id;

    -- Clean up partner's couple reference and flag notification
    IF v_partner_id IS NOT NULL THEN
      UPDATE public.users
      SET
        couple_id = NULL,
        partner_deleted_notice = TRUE
      WHERE id = v_partner_id;
    END IF;

    -- Delete the couples row and cascade delete shared resources if no users remain in it
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$;


-- =====================================================================
-- 2. FIX USERS SELECT RLS POLICY (VALIDATE VIA COUPLES TABLE)
-- =====================================================================
DROP POLICY IF EXISTS "Enable select for self and partner" ON public.users;

CREATE POLICY "Enable select for self and partner" ON public.users
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR
    (couple_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.couples c
      WHERE c.id = public.users.couple_id
        AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
    ))
  );


-- =====================================================================
-- 3. SECURE SECURITY DEFINER FUNCTIONS (ENFORCE AUTHENTICATION)
-- =====================================================================

-- A. get_user_couple_id
CREATE OR REPLACE FUNCTION public.get_user_couple_id(user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_couple_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  
  -- Verify caller is querying their own ID or their partner's
  IF auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.couples c ON c.id = u.couple_id
    WHERE u.id = user_id
      AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
  ) THEN
    SELECT couple_id INTO v_couple_id FROM public.users WHERE id = user_id;
    RETURN v_couple_id::text;
  ELSE
    RAISE EXCEPTION 'Unauthorized';
  END IF;
END;
$$;

-- B. is_member_of_couple
CREATE OR REPLACE FUNCTION public.is_member_of_couple(couple_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.couples c ON c.id = u.couple_id
    WHERE u.id = auth.uid()
      AND u.couple_id = is_member_of_couple.couple_id
      AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
      AND c.status != 'archived'
  );
END;
$$;

-- C. delete_current_user
CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_user_id := auth.uid();
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN json_build_object('success', true);
END;
$$;

-- D. create_relationship_workspace
CREATE OR REPLACE FUNCTION public.create_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_couple_id uuid;
  v_pairing_code text;
  v_lookup_key text;
  v_secret_formatted text;
  v_secret_clean text;
  v_user_couple_id uuid;
  v_code_exists boolean;
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();

  LOOP
    v_pairing_code := '';
    FOR i IN 1..6 LOOP
      v_pairing_code := v_pairing_code || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS(SELECT 1 FROM public.couples WHERE pairing_code = v_pairing_code) INTO v_code_exists;
    SELECT EXISTS(SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;

    IF NOT v_code_exists AND NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  INSERT INTO public.couples (id, status, partner_a_id, pairing_code, recovery_lookup_key, recovery_code_hash)
  VALUES (
    v_couple_id,
    'waiting',
    auth.uid(),
    v_pairing_code,
    v_lookup_key,
    crypt(v_secret_clean, gen_salt('bf', 10))
  );

  UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- E. join_relationship_with_code
CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_row public.couples%ROWTYPE;
  v_user_couple_id uuid;
  v_attempts integer;
  v_locked_until timestamp with time zone;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 1. Check rate limiting
  SELECT attempts, locked_until INTO v_attempts, v_locked_until
  FROM public.failed_pairing_attempts
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
  END IF;

  -- 2. Lock caller row
  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- 3. Find and lock couples row
  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE upper(pairing_code) = upper(trim(p_pairing_code))
    AND status = 'waiting'
    AND partner_b_id IS NULL
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    -- Log failed attempt
    INSERT INTO public.failed_pairing_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      attempts = failed_pairing_attempts.attempts + 1,
      locked_until = CASE WHEN failed_pairing_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
      updated_at = now();

    RAISE EXCEPTION 'Invalid or expired pairing code';
  END IF;

  IF v_couple_row.partner_a_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot pair with yourself';
  END IF;

  -- 4. Success: Reset attempts and update records
  INSERT INTO public.failed_pairing_attempts (user_id, attempts, locked_until)
  VALUES (auth.uid(), 0, NULL)
  ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

  UPDATE public.couples
  SET
    partner_b_id = auth.uid(),
    status = 'active',
    pairing_code = NULL
  WHERE id = v_couple_row.id;

  UPDATE public.users
  SET couple_id = v_couple_row.id
  WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_row.id,
    'partner_id', v_couple_row.partner_a_id
  );
END;
$$;

-- F. recover_relationship_with_code
CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_id uuid;
  v_couple_row record;
  v_attempts integer;
  v_locked_until timestamp with time zone;
  v_user_couple_id uuid;
  v_success boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT couple_id INTO v_user_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_user_couple_id IS NOT NULL THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  SELECT attempts, locked_until INTO v_attempts, v_locked_until
  FROM public.failed_recovery_attempts
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed attempts. Try again after %', v_locked_until;
  END IF;

  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(replace(v_secret, '-', ''), ' ', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        IF v_couple_row.partner_a_id = auth.uid() OR v_couple_row.partner_b_id = auth.uid() OR v_couple_row.partner_a_id IS NULL OR v_couple_row.partner_b_id IS NULL THEN
          v_success := true;
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_success THEN
    IF v_couple_row.partner_a_id IS NULL AND (v_couple_row.partner_b_id IS NULL OR v_couple_row.partner_b_id != auth.uid()) THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    ELSIF v_couple_row.partner_b_id IS NULL AND (v_couple_row.partner_a_id IS NULL OR v_couple_row.partner_a_id != auth.uid()) THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    ELSE
      UPDATE public.couples SET status = 'active' WHERE id = v_couple_row.id;
    END IF;

    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 0, NULL)
    ON CONFLICT (user_id) DO UPDATE SET attempts = 0, locked_until = NULL;

    UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

    RETURN json_build_object(
      'success', true,
      'couple_id', v_couple_row.id
    );
  ELSE
    INSERT INTO public.failed_recovery_attempts (user_id, attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      attempts = failed_recovery_attempts.attempts + 1,
      locked_until = CASE WHEN failed_recovery_attempts.attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END,
      updated_at = now();

    RAISE EXCEPTION 'Invalid recovery code';
  END IF;
END;
$$;

-- G. regenerate_recovery_code
CREATE OR REPLACE FUNCTION public.regenerate_recovery_code()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_couple_id uuid;
  v_lookup_key text;
  v_secret_clean text;
  v_secret_formatted text;
  v_lookup_exists boolean;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RAISE EXCEPTION 'Not in a relationship';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.couples WHERE id = v_couple_id AND (partner_a_id = auth.uid() OR partner_b_id = auth.uid()) FOR UPDATE
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  LOOP
    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;

    SELECT EXISTS (SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) INTO v_lookup_exists;
    IF NOT v_lookup_exists THEN
      EXIT;
    END IF;
  END LOOP;

  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;

  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  UPDATE public.couples
  SET
    recovery_lookup_key = v_lookup_key,
    recovery_code_hash = crypt(v_secret_clean, gen_salt('bf', 10))
  WHERE id = v_couple_id;

  RETURN json_build_object(
    'success', true,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

-- H. disconnect_relationship_workspace
CREATE OR REPLACE FUNCTION public.disconnect_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_id uuid;
  v_other_connected boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not in a relationship');
  END IF;

  PERFORM 1 FROM public.couples WHERE id = v_couple_id FOR UPDATE;

  UPDATE public.users SET couple_id = NULL WHERE id = auth.uid();

  UPDATE public.couples
  SET
    partner_a_id = CASE WHEN partner_a_id = auth.uid() THEN NULL ELSE partner_a_id END,
    partner_b_id = CASE WHEN partner_b_id = auth.uid() THEN NULL ELSE partner_b_id END
  WHERE id = v_couple_id;

  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE couple_id = v_couple_id AND id != auth.uid()
  ) INTO v_other_connected;

  IF NOT v_other_connected THEN
    UPDATE public.couples SET status = 'disconnected' WHERE id = v_couple_id;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;


-- =====================================================================
-- 4. PROTECT PREMIUM STATUS FROM CLIENT-SIDE UPDATES
-- =====================================================================
CREATE OR REPLACE FUNCTION public.protect_premium_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Revert NEW.is_premium to OLD.is_premium if the caller is an authenticated client
  IF NEW.is_premium IS DISTINCT FROM OLD.is_premium AND auth.role() = 'authenticated' THEN
    NEW.is_premium := OLD.is_premium;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_premium_status ON public.couples;
CREATE TRIGGER trg_protect_premium_status
  BEFORE UPDATE ON public.couples
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_premium_status();


-- =====================================================================
-- 5. PRESERVE SHARED HISTORY (CHANGE FOREIGN KEYS TO ON DELETE SET NULL)
-- =====================================================================

-- love_notes table constraint
ALTER TABLE public.love_notes
  DROP CONSTRAINT IF EXISTS love_notes_sender_id_fkey;

ALTER TABLE public.love_notes
  ADD CONSTRAINT love_notes_sender_id_fkey
  FOREIGN KEY (sender_id)
  REFERENCES auth.users(id)
  ON DELETE SET NULL;

-- moods table constraint
ALTER TABLE public.moods
  DROP CONSTRAINT IF EXISTS moods_user_id_fkey;

ALTER TABLE public.moods
  ADD CONSTRAINT moods_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE SET NULL;


-- FILE: 20260711100000_database_indexing_optimizations.sql
-- Migration: Database Indexing Optimizations for Performance & RLS Hardening
-- Created At: 2026-07-11

-- 1. Index users(couple_id)
-- Reason: Heavily queried by RLS checks (e.g. is_member_of_couple) and the users SELECT RLS policy.
-- Prevents full table sequential scans on users when validating couple memberships.
CREATE INDEX IF NOT EXISTS users_couple_id_idx ON public.users (couple_id);


-- 3. Index couples(partner_a_id)
-- Reason: Checked in is_member_of_couple() to verify active couple memberships for auth.uid().
CREATE INDEX IF NOT EXISTS couples_partner_a_id_idx ON public.couples (partner_a_id);

-- 4. Index couples(partner_b_id)
-- Reason: Checked in is_member_of_couple() to verify active couple memberships for auth.uid().
CREATE INDEX IF NOT EXISTS couples_partner_b_id_idx ON public.couples (partner_b_id);

-- 5. Index topic_cards(couple_id)
-- Reason: Speeds up custom topic cards loading, filtering, and shuffling scoped to the relationship workspace.
CREATE INDEX IF NOT EXISTS topic_cards_couple_id_idx ON public.topic_cards (couple_id);

-- 6. Index user_fcm_tokens(user_id)
-- Reason: Speeds up fcm token lookup when sending notifications to a user, and clean up on login/logout.
CREATE INDEX IF NOT EXISTS user_fcm_tokens_user_id_idx ON public.user_fcm_tokens (user_id);

-- 7. Index moods(user_id)
-- Reason: Speeds up daily mood history retrieval and analytics/graphs scoped to a specific user.
CREATE INDEX IF NOT EXISTS moods_user_id_idx ON public.moods (user_id);

-- 8. Index daily_questions(couple_id)
-- Reason: Composite primary key (date, couple_id) starts with date, making searches by couple_id alone inefficient.
CREATE INDEX IF NOT EXISTS daily_questions_couple_id_idx ON public.daily_questions (couple_id);

-- 9. Index love_notes(sender_id)
-- Reason: Speeds up filtering notes by sender, and improves CASCADE delete performance when users are deleted.
CREATE INDEX IF NOT EXISTS love_notes_sender_id_idx ON public.love_notes (sender_id);

-- 10. Index license_details(creator_id)
-- Reason: Speeds up certificate lookup by relationship creator.
CREATE INDEX IF NOT EXISTS license_details_creator_id_idx ON public.license_details (creator_id);




-- FILE: 20260712000000_fix_relationship_recovery.sql
CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  v_couple_id := OLD.couple_id;

  IF v_couple_id IS NOT NULL THEN
    -- Look up partner from couples table since partner_id is dropped
    SELECT 
      CASE WHEN partner_a_id = OLD.id THEN partner_b_id ELSE partner_a_id END
    INTO v_partner_id
    FROM public.couples
    WHERE id = v_couple_id;

    -- Notify the remaining partner, keeping couple_id intact to preserve the workspace
    IF v_partner_id IS NOT NULL THEN
      UPDATE public.users
      SET partner_deleted_notice = TRUE
      WHERE id = v_partner_id;
    END IF;

    -- Clean up couples row only if no users remain in it
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$;


-- FILE: 20260712000001_refactor_users_profiles.sql
-- Migration: Refactor Users, Couples, and License Tables for Slot-Based Identity
-- Created: 2026-07-12

-- 1. Add profile columns to public.users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gender text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS birthdate timestamptz;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS address text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS nationality text DEFAULT 'Love Land'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS weight text DEFAULT '—'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS height text DEFAULT '—'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS blood_type text DEFAULT '—'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS eye_color text DEFAULT '—'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS conditions text DEFAULT 'Madly in Love'::text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS date_issued timestamptz;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS signature text;

-- 2. Add email slots to couples table
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_a_email text;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS partner_b_email text;

-- 3. Add slot tracking to shared history tables and update FKs to ON DELETE SET NULL
ALTER TABLE public.love_notes DROP CONSTRAINT IF EXISTS love_notes_sender_id_fkey;
ALTER TABLE public.love_notes ADD COLUMN IF NOT EXISTS sender_slot text; -- 'partner_a' | 'partner_b'
ALTER TABLE public.love_notes ADD CONSTRAINT love_notes_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.moods DROP CONSTRAINT IF EXISTS moods_user_id_fkey;
ALTER TABLE public.moods ADD COLUMN IF NOT EXISTS user_slot text; -- 'partner_a' | 'partner_b'
ALTER TABLE public.moods ADD CONSTRAINT moods_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 4. Clean up license_details table (metadata only)
DROP INDEX IF EXISTS public.license_details_creator_id_idx;
ALTER TABLE public.license_details DROP COLUMN IF EXISTS creator_id;

-- 5. RLS Policies Hardening
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.users;
CREATE POLICY "Enable select for authenticated users" ON public.users 
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable insert for own profile" ON public.users;
CREATE POLICY "Enable insert for own profile" ON public.users 
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Enable update for own profile" ON public.users;
CREATE POLICY "Enable update for own profile" ON public.users 
  FOR UPDATE TO authenticated 
  USING (
    auth.uid() = id 
    OR 
    (couple_id IS NOT NULL AND couple_id = (SELECT u.couple_id FROM public.users u WHERE u.id = auth.uid()))
  );

DROP POLICY IF EXISTS "Enable delete for own profile" ON public.users;
CREATE POLICY "Enable delete for own profile" ON public.users 
  FOR DELETE TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "Enable update for own profile or pairing partner" ON public.users;

-- couples table policies
ALTER TABLE public.couples ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable select for couple members" ON public.couples;
CREATE POLICY "Enable select for couple members" ON public.couples 
  FOR SELECT TO authenticated USING (auth.uid() = partner_a_id OR auth.uid() = partner_b_id);

DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.couples;
CREATE POLICY "Enable insert for authenticated users" ON public.couples 
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for couple members" ON public.couples;
CREATE POLICY "Enable update for couple members" ON public.couples 
  FOR UPDATE TO authenticated USING (auth.uid() = partner_a_id OR auth.uid() = partner_b_id)
  WITH CHECK (auth.uid() = partner_a_id OR auth.uid() = partner_b_id);

-- license_details table policies
ALTER TABLE public.license_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable select for couple members" ON public.license_details;
CREATE POLICY "Enable select for couple members" ON public.license_details 
  FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.couple_id = license_details.couple_id));

DROP POLICY IF EXISTS "Enable insert for couple members" ON public.license_details;
CREATE POLICY "Enable insert for couple members" ON public.license_details 
  FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.couple_id = license_details.couple_id));

DROP POLICY IF EXISTS "Enable update for couple members" ON public.license_details;
CREATE POLICY "Enable update for couple members" ON public.license_details 
  FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.couple_id = license_details.couple_id));

-- Storage objects read policies (security validation)
DROP POLICY IF EXISTS "Allow public read from love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated read from love-notes, timeline, vault" ON storage.objects;
CREATE POLICY "Allow authenticated read from love-notes, timeline, vault" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

-- 6. Re-create RPC Functions
CREATE OR REPLACE FUNCTION public.create_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_couple_id uuid;
  v_pairing_code text;
  v_lookup_key text;
  v_secret_clean text;
  v_secret_formatted text;
  v_user_email text;
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  i integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_couple_id := gen_random_uuid();

  LOOP
    v_pairing_code := '';
    v_lookup_key := '';
    FOR i IN 1..6 LOOP
      v_pairing_code := v_pairing_code || substr(chars, floor(random() * 36)::integer + 1, 1);
      v_lookup_key := v_lookup_key || substr(chars, floor(random() * 36)::integer + 1, 1);
    END LOOP;
    
    IF NOT EXISTS(SELECT 1 FROM public.couples WHERE pairing_code = v_pairing_code) AND
       NOT EXISTS(SELECT 1 FROM public.couples WHERE recovery_lookup_key = v_lookup_key) THEN
      EXIT;
    END IF;
  END LOOP;

  v_secret_clean := '';
  FOR i IN 1..16 LOOP
    v_secret_clean := v_secret_clean || substr(chars, floor(random() * 36)::integer + 1, 1);
  END LOOP;
  v_secret_formatted := substr(v_secret_clean, 1, 4) || '-' ||
                        substr(v_secret_clean, 5, 4) || '-' ||
                        substr(v_secret_clean, 9, 4) || '-' ||
                        substr(v_secret_clean, 13, 4);

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  INSERT INTO public.couples (id, status, partner_a_id, partner_a_email, pairing_code, recovery_lookup_key, recovery_code_hash)
  VALUES (v_couple_id, 'waiting', auth.uid(), v_user_email, v_pairing_code, v_lookup_key, crypt(v_secret_clean, gen_salt('bf', 10)));

  UPDATE public.users SET couple_id = v_couple_id WHERE id = auth.uid();

  INSERT INTO public.license_details (couple_id, certificate_number)
  VALUES (v_couple_id, 'DT-' || to_char(now(), 'YYYYMMDD') || '-' || substr(v_couple_id::text, 1, 4));

  RETURN json_build_object(
    'success', true,
    'couple_id', v_couple_id,
    'pairing_code', v_pairing_code,
    'recovery_code', v_lookup_key || '-' || v_secret_formatted
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_relationship_with_code(p_pairing_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_row public.couples%ROWTYPE;
  v_user_email text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  SELECT * INTO v_couple_row
  FROM public.couples
  WHERE upper(pairing_code) = upper(trim(p_pairing_code))
    AND status = 'waiting'
    AND partner_b_id IS NULL
  FOR UPDATE;

  IF v_couple_row.id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired pairing code';
  END IF;

  IF v_couple_row.partner_a_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot pair with yourself';
  END IF;

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  UPDATE public.couples
  SET partner_b_id = auth.uid(), partner_b_email = v_user_email, status = 'active', pairing_code = NULL
  WHERE id = v_couple_row.id;

  UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'couple_id', v_couple_row.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_row record;
  v_user_email text;
  v_success boolean := false;
  v_assigned_slot text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(v_secret, '-', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        v_success := true;
      END IF;
    END IF;
  END IF;

  IF NOT v_success THEN
    RAISE EXCEPTION 'Invalid recovery code';
  END IF;

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  -- Deterministic Assignment via Recorded Emails
  IF v_couple_row.partner_a_email = v_user_email THEN
    UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_a';
  ELSIF v_couple_row.partner_b_email = v_user_email THEN
    UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_b';
  ELSE
    IF v_couple_row.partner_a_id IS NULL THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), partner_a_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_a';
    ELSIF v_couple_row.partner_b_id IS NULL THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), partner_b_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_b';
    ELSE
      RAISE EXCEPTION 'No vacant slot available in this relationship workspace';
    END IF;
  END IF;

  UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'couple_id', v_couple_row.id, 'slot', v_assigned_slot);
END;
$$;

CREATE OR REPLACE FUNCTION public.disconnect_relationship_workspace()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_couple_id uuid;
  v_other_connected boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT couple_id INTO v_couple_id FROM public.users WHERE id = auth.uid() FOR UPDATE;
  IF v_couple_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not in a relationship');
  END IF;

  PERFORM 1 FROM public.couples WHERE id = v_couple_id FOR UPDATE;

  UPDATE public.users SET couple_id = NULL WHERE id = auth.uid();

  UPDATE public.couples
  SET
    partner_a_id = CASE WHEN partner_a_id = auth.uid() THEN NULL ELSE partner_a_id END,
    partner_b_id = CASE WHEN partner_b_id = auth.uid() THEN NULL ELSE partner_b_id END
  WHERE id = v_couple_id;

  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE couple_id = v_couple_id AND id != auth.uid()
  ) INTO v_other_connected;

  IF NOT v_other_connected THEN
    UPDATE public.couples SET status = 'disconnected' WHERE id = v_couple_id;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;


-- FILE: 20260712000002_fix_rls_recursion.sql
-- Migration: Fix RLS Policy Infinite Recursion
-- Created: 2026-07-12

-- 1. Drop the redundant and recursive SELECT policy on users
DROP POLICY IF EXISTS "Enable select for self and partner" ON public.users;

-- 2. Drop and recreate the UPDATE policy on users to use couples table checks instead of self-referencing users table checks
DROP POLICY IF EXISTS "Enable update for own profile" ON public.users;
CREATE POLICY "Enable update for own profile" ON public.users 
  FOR UPDATE TO authenticated 
  USING (
    auth.uid() = id 
    OR 
    (couple_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.couples c 
      WHERE c.id = public.users.couple_id 
        AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
    ))
  );

-- 3. Automatic user profile creation trigger on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, display_name, couple_id)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'name', 'New User'),
    NULL
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Backfill public.users for any existing auth.users
INSERT INTO public.users (id, display_name)
SELECT 
  id, 
  COALESCE(raw_user_meta_data->>'display_name', raw_user_meta_data->>'name', 'New User')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 5. Add relationship metadata columns to license_details and clean up legacy profile fields
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS certificate_number text;
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS issue_date timestamptz DEFAULT now();
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS anniversary timestamptz;
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS theme text DEFAULT 'classic';
ALTER TABLE public.license_details ADD COLUMN IF NOT EXISTS relationship_title text DEFAULT 'Together Forever';

-- Clean up profile fields from license_details
ALTER TABLE public.license_details 
  DROP COLUMN IF EXISTS your_name,
  DROP COLUMN IF EXISTS partner_name,
  DROP COLUMN IF EXISTS your_gender,
  DROP COLUMN IF EXISTS partner_gender,
  DROP COLUMN IF EXISTS your_phone,
  DROP COLUMN IF EXISTS partner_phone,
  DROP COLUMN IF EXISTS your_birthdate,
  DROP COLUMN IF EXISTS partner_birthdate,
  DROP COLUMN IF EXISTS your_address,
  DROP COLUMN IF EXISTS partner_address,
  DROP COLUMN IF EXISTS your_nationality,
  DROP COLUMN IF EXISTS partner_nationality,
  DROP COLUMN IF EXISTS your_weight,
  DROP COLUMN IF EXISTS partner_weight,
  DROP COLUMN IF EXISTS your_height,
  DROP COLUMN IF EXISTS partner_height,
  DROP COLUMN IF EXISTS your_blood_type,
  DROP COLUMN IF EXISTS partner_blood_type,
  DROP COLUMN IF EXISTS your_eye_color,
  DROP COLUMN IF EXISTS partner_eye_color,
  DROP COLUMN IF EXISTS your_conditions,
  DROP COLUMN IF EXISTS partner_conditions,
  DROP COLUMN IF EXISTS your_date_issued,
  DROP COLUMN IF EXISTS partner_date_issued,
  DROP COLUMN IF EXISTS your_signature,
  DROP COLUMN IF EXISTS partner_signature,
  DROP COLUMN IF EXISTS your_avatar_path,
  DROP COLUMN IF EXISTS partner_avatar_path;




-- FILE: 20260713000000_audit_p1_hardening.sql
-- Migration: Audit P1 Hardening
-- Created: 2026-07-13
-- Addresses: Audit issues 1.1, 1.5, 2.2, 3.1, 7.1, 7.2, 8.1, 8.5, 14.3

-- ============================================================
-- 1A. Recovery Code Brute-Force Rate Limiting (Audit 7.1)
-- ============================================================
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS failed_recovery_attempts integer DEFAULT 0;
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_locked_until timestamptz;

-- ============================================================
-- 1B. Unique Index on recovery_lookup_key (Audit 2.2, 8.1)
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_couples_recovery_lookup_key
  ON public.couples (recovery_lookup_key) WHERE recovery_lookup_key IS NOT NULL;

-- ============================================================
-- 1C + 1D. Idempotent Deletion Trigger with Slot/Email Clearing (Audit 1.5, 8.5)
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  v_couple_id := OLD.couple_id;

  IF v_couple_id IS NOT NULL THEN
    -- Look up partner from couples table
    SELECT
      CASE WHEN partner_a_id = OLD.id THEN partner_b_id ELSE partner_a_id END
    INTO v_partner_id
    FROM public.couples
    WHERE id = v_couple_id;

    -- Notify the remaining partner
    IF v_partner_id IS NOT NULL THEN
      UPDATE public.users
      SET partner_deleted_notice = TRUE
      WHERE id = v_partner_id;
    END IF;

    -- Clear the deleted user's slot AND email from the couples row (Audit 1.5)
    UPDATE public.couples
    SET
      partner_a_id    = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_id END,
      partner_b_id    = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_id END,
      partner_a_email = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_email END,
      partner_b_email = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_email END
    WHERE id = v_couple_id;

    -- Clean up couples row only if no users remain in it (idempotent guard - Audit 8.5)
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$;

-- ============================================================
-- 1E. Verify love_notes FK is ON DELETE SET NULL (Audit 2.1, 14.3)
-- Already applied in 20260712000001 migration. Re-apply idempotently.
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'love_notes_sender_id_fkey'
      AND table_name = 'love_notes'
  ) THEN
    -- Check if the current FK has CASCADE instead of SET NULL
    IF EXISTS (
      SELECT 1 FROM information_schema.referential_constraints
      WHERE constraint_name = 'love_notes_sender_id_fkey'
        AND delete_rule = 'CASCADE'
    ) THEN
      ALTER TABLE public.love_notes DROP CONSTRAINT love_notes_sender_id_fkey;
      ALTER TABLE public.love_notes ADD CONSTRAINT love_notes_sender_id_fkey
        FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- ============================================================
-- 1F. Couples SELECT RLS — Explicit auth.uid() guard (Audit 7.2)
-- ============================================================
DROP POLICY IF EXISTS "Enable select for couple members" ON public.couples;
CREATE POLICY "Enable select for couple members" ON public.couples
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL AND (auth.uid() = partner_a_id OR auth.uid() = partner_b_id));

-- ============================================================
-- 1A (continued). Update recover_relationship_with_code with rate limiting
-- ============================================================
CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_row record;
  v_user_email text;
  v_success boolean := false;
  v_assigned_slot text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(v_secret, '-', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      -- Rate limiting check (Audit 7.1)
      IF v_couple_row.recovery_locked_until IS NOT NULL
         AND v_couple_row.recovery_locked_until > now() THEN
        RAISE EXCEPTION 'Too many failed attempts. Try again after %',
          to_char(v_couple_row.recovery_locked_until, 'HH24:MI:SS');
      END IF;

      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        v_success := true;
        -- Reset failed attempts on success
        UPDATE public.couples
        SET failed_recovery_attempts = 0, recovery_locked_until = NULL
        WHERE id = v_couple_row.id;
      ELSE
        -- Increment failed attempts
        UPDATE public.couples
        SET
          failed_recovery_attempts = COALESCE(v_couple_row.failed_recovery_attempts, 0) + 1,
          recovery_locked_until = CASE
            WHEN COALESCE(v_couple_row.failed_recovery_attempts, 0) + 1 >= 5
            THEN now() + interval '15 minutes'
            ELSE NULL
          END
        WHERE id = v_couple_row.id;
      END IF;
    END IF;
  END IF;

  IF NOT v_success THEN
    RAISE EXCEPTION 'Invalid recovery code';
  END IF;

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  -- Deterministic Assignment via Recorded Emails
  IF v_couple_row.partner_a_email = v_user_email THEN
    UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_a';
  ELSIF v_couple_row.partner_b_email = v_user_email THEN
    UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_b';
  ELSE
    IF v_couple_row.partner_a_id IS NULL THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), partner_a_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_a';
    ELSIF v_couple_row.partner_b_id IS NULL THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), partner_b_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_b';
    ELSE
      RAISE EXCEPTION 'No vacant slot available in this relationship workspace';
    END IF;
  END IF;

  UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'couple_id', v_couple_row.id, 'slot', v_assigned_slot);
END;
$$;


-- FILE: 20260713000001_secure_storage_policies.sql
-- Migration: Secure Storage Buckets Write Policies
-- Created: 2026-07-13
-- Addresses: Audit issue 7.3, 7.4 (Broken Object Level Authorization on Storage)

-- 1. Drop legacy/permissive write policies on love-notes, timeline, vault-photos
DROP POLICY IF EXISTS "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects;

-- 2. Create secured write policies for love-notes, timeline, vault-photos
CREATE POLICY "Allow authenticated uploads to love-notes, timeline, vault" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated updates to love-notes, timeline, vault" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated deletes from love-notes, timeline, vault" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id IN ('love-notes', 'timeline', 'vault-photos')
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

-- 3. Drop legacy/permissive write policies for avatars
DROP POLICY IF EXISTS "Allow authenticated uploads to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from avatars" ON storage.objects;

-- 4. Create secured write policies for avatars
CREATE POLICY "Allow authenticated uploads to avatars" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated updates to avatars" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Allow authenticated deletes from avatars" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[2] = (SELECT couple_id::text FROM public.users WHERE id = auth.uid())
    )
  );


-- FILE: 20260808000000_security_remediation.sql
-- Migration: Security Remediation (C-2, C-4, H-2)
-- Created: 2026-08-08

-- ============================================================
-- 1. Fix Users SELECT RLS Policy (Audit C-4)
-- Restrict SELECT to own profile or partner profile in same couple
-- ============================================================
DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.users;
DROP POLICY IF EXISTS "Enable select for self and partner" ON public.users;

CREATE POLICY "Enable select for self and partner" ON public.users
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id
    OR
    (couple_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.couples c
      WHERE c.id = public.users.couple_id
        AND (c.partner_a_id = auth.uid() OR c.partner_b_id = auth.uid())
    ))
  );

-- ============================================================
-- 2. Fix Users UPDATE RLS Policy (Audit C-2)
-- Restrict direct UPDATE strictly to own profile. Partner updates must use update_partner_profile RPC.
-- ============================================================
DROP POLICY IF EXISTS "Enable update for own profile" ON public.users;

CREATE POLICY "Enable update for own profile" ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- 3. Dedicated RPC Function for Partner Profile Updates (Audit C-2)
-- Whitelists profile columns and verifies target is caller's partner in same workspace.
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_partner_profile(
  p_target_user_id uuid,
  p_updates jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller_couple_id uuid;
  v_target_couple_id uuid;
  v_allowed_keys text[] := ARRAY[
    'display_name', 'gender', 'phone', 'birthdate', 'address',
    'nationality', 'weight', 'height', 'blood_type', 'eye_color',
    'conditions', 'date_issued', 'signature', 'avatar_url'
  ];
  v_key text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF auth.uid() = p_target_user_id THEN
    RAISE EXCEPTION 'Use self-update for your own profile';
  END IF;

  -- Get caller's couple_id
  SELECT couple_id INTO v_caller_couple_id FROM public.users WHERE id = auth.uid();
  IF v_caller_couple_id IS NULL THEN
    RAISE EXCEPTION 'Caller is not in a relationship workspace';
  END IF;

  -- Verify target is caller's partner in the same couple workspace
  SELECT couple_id INTO v_target_couple_id FROM public.users WHERE id = p_target_user_id;
  IF v_target_couple_id IS NULL OR v_target_couple_id != v_caller_couple_id THEN
    RAISE EXCEPTION 'Target user is not your partner in this relationship';
  END IF;

  -- Validate all keys in p_updates are whitelisted
  FOR v_key IN SELECT jsonb_object_keys(p_updates) LOOP
    IF NOT (v_key = ANY(v_allowed_keys)) THEN
      RAISE EXCEPTION 'Modification of column "%" is prohibited for partner updates', v_key;
    END IF;
  END LOOP;

  -- Perform safe update
  UPDATE public.users
  SET
    display_name = CASE WHEN p_updates ? 'display_name' THEN p_updates->>'display_name' ELSE display_name END,
    gender       = CASE WHEN p_updates ? 'gender' THEN p_updates->>'gender' ELSE gender END,
    phone        = CASE WHEN p_updates ? 'phone' THEN p_updates->>'phone' ELSE phone END,
    birthdate    = CASE WHEN p_updates ? 'birthdate' THEN (p_updates->>'birthdate')::timestamptz ELSE birthdate END,
    address      = CASE WHEN p_updates ? 'address' THEN p_updates->>'address' ELSE address END,
    nationality  = CASE WHEN p_updates ? 'nationality' THEN p_updates->>'nationality' ELSE nationality END,
    weight       = CASE WHEN p_updates ? 'weight' THEN p_updates->>'weight' ELSE weight END,
    height       = CASE WHEN p_updates ? 'height' THEN p_updates->>'height' ELSE height END,
    blood_type   = CASE WHEN p_updates ? 'blood_type' THEN p_updates->>'blood_type' ELSE blood_type END,
    eye_color    = CASE WHEN p_updates ? 'eye_color' THEN p_updates->>'eye_color' ELSE eye_color END,
    conditions   = CASE WHEN p_updates ? 'conditions' THEN p_updates->>'conditions' ELSE conditions END,
    date_issued  = CASE WHEN p_updates ? 'date_issued' THEN (p_updates->>'date_issued')::timestamptz ELSE date_issued END,
    signature    = CASE WHEN p_updates ? 'signature' THEN p_updates->>'signature' ELSE signature END,
    avatar_url   = CASE WHEN p_updates ? 'avatar_url' THEN p_updates->>'avatar_url' ELSE avatar_url END
  WHERE id = p_target_user_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ============================================================
-- 4. Restrict Couples INSERT RLS Policy (Audit H-2)
-- Deny direct inserts into public.couples table. Workspaces must be created via RPC.
-- ============================================================
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.couples;

CREATE POLICY "Deny direct insert on couples" ON public.couples
  FOR INSERT TO authenticated
  WITH CHECK (false);


-- FILE: 20260808000001_recovery_hardening.sql
-- Migration: Recovery Hardening (H-3, H-4, H-5)
-- Created: 2026-08-08

-- ============================================================
-- 1. Add recovery_code_generated_at column (Audit H-3)
-- ============================================================
ALTER TABLE public.couples ADD COLUMN IF NOT EXISTS recovery_code_generated_at timestamptz DEFAULT now();

-- ============================================================
-- 2. Per-User Recovery Rate Limiting Table (Audit H-5)
-- Prevents attackers from bypassing rate limits by switching accounts
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_recovery_attempts (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  failed_attempts integer DEFAULT 0,
  locked_until timestamptz
);

ALTER TABLE public.user_recovery_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable select for own recovery attempts" ON public.user_recovery_attempts;
CREATE POLICY "Enable select for own recovery attempts" ON public.user_recovery_attempts
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- ============================================================
-- 3. Hardened recover_relationship_with_code RPC Function (Audit H-3, H-5)
-- Includes 90-day expiration and layered per-user + per-couple rate limiting
-- ============================================================
CREATE OR REPLACE FUNCTION public.recover_relationship_with_code(p_recovery_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_code_clean text;
  v_first_hyphen_pos integer;
  v_lookup_key text;
  v_secret text;
  v_secret_clean text;
  v_couple_row record;
  v_user_email text;
  v_success boolean := false;
  v_assigned_slot text;
  v_user_attempts record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND couple_id IS NOT NULL) THEN
    RAISE EXCEPTION 'User is already in a relationship';
  END IF;

  -- Layer 1: Check Per-User Rate Limit (Audit H-5)
  SELECT * INTO v_user_attempts FROM public.user_recovery_attempts WHERE user_id = auth.uid();
  IF v_user_attempts.locked_until IS NOT NULL AND v_user_attempts.locked_until > now() THEN
    RAISE EXCEPTION 'Too many failed recovery attempts from this account. Try again after %',
      to_char(v_user_attempts.locked_until, 'HH24:MI:SS');
  END IF;

  v_code_clean := upper(trim(p_recovery_code));
  v_first_hyphen_pos := position('-' in v_code_clean);

  IF v_first_hyphen_pos > 1 THEN
    v_lookup_key := substr(v_code_clean, 1, v_first_hyphen_pos - 1);
    v_secret := substr(v_code_clean, v_first_hyphen_pos + 1);
    v_secret_clean := replace(v_secret, '-', '');

    SELECT * INTO v_couple_row
    FROM public.couples
    WHERE recovery_lookup_key = v_lookup_key
    FOR UPDATE;

    IF v_couple_row.id IS NOT NULL THEN
      -- Layer 2: Check Per-Couple Rate Limit
      IF v_couple_row.recovery_locked_until IS NOT NULL
         AND v_couple_row.recovery_locked_until > now() THEN
        RAISE EXCEPTION 'Too many failed attempts on this recovery key. Try again after %',
          to_char(v_couple_row.recovery_locked_until, 'HH24:MI:SS');
      END IF;

      -- Check Expiration (90 Days - Audit H-3)
      IF v_couple_row.recovery_code_generated_at IS NOT NULL
         AND v_couple_row.recovery_code_generated_at < (now() - interval '90 days') THEN
        RAISE EXCEPTION 'Recovery code has expired (valid for 90 days). Request a new recovery code.';
      END IF;

      -- Verify Bcrypt Hash
      IF v_couple_row.recovery_code_hash = crypt(v_secret_clean, v_couple_row.recovery_code_hash) THEN
        v_success := true;
        -- Reset per-couple rate limit on success
        UPDATE public.couples
        SET failed_recovery_attempts = 0, recovery_locked_until = NULL
        WHERE id = v_couple_row.id;
      ELSE
        -- Increment per-couple rate limit
        UPDATE public.couples
        SET
          failed_recovery_attempts = COALESCE(v_couple_row.failed_recovery_attempts, 0) + 1,
          recovery_locked_until = CASE
            WHEN COALESCE(v_couple_row.failed_recovery_attempts, 0) + 1 >= 5
            THEN now() + interval '15 minutes'
            ELSE NULL
          END
        WHERE id = v_couple_row.id;
      END IF;
    END IF;
  END IF;

  IF NOT v_success THEN
    -- Increment per-user rate limit on failure (Audit H-5)
    INSERT INTO public.user_recovery_attempts (user_id, failed_attempts, locked_until)
    VALUES (auth.uid(), 1, NULL)
    ON CONFLICT (user_id) DO UPDATE SET
      failed_attempts = public.user_recovery_attempts.failed_attempts + 1,
      locked_until = CASE
        WHEN public.user_recovery_attempts.failed_attempts + 1 >= 5 THEN now() + interval '15 minutes'
        ELSE NULL
      END;

    RAISE EXCEPTION 'Invalid recovery code';
  END IF;

  -- Reset per-user rate limit on success
  UPDATE public.user_recovery_attempts
  SET failed_attempts = 0, locked_until = NULL
  WHERE user_id = auth.uid();

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();

  -- Deterministic Assignment via Recorded Emails
  IF v_couple_row.partner_a_email = v_user_email THEN
    UPDATE public.couples SET partner_a_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_a';
  ELSIF v_couple_row.partner_b_email = v_user_email THEN
    UPDATE public.couples SET partner_b_id = auth.uid(), status = 'active' WHERE id = v_couple_row.id;
    v_assigned_slot := 'partner_b';
  ELSE
    IF v_couple_row.partner_a_id IS NULL THEN
      UPDATE public.couples SET partner_a_id = auth.uid(), partner_a_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_a';
    ELSIF v_couple_row.partner_b_id IS NULL THEN
      UPDATE public.couples SET partner_b_id = auth.uid(), partner_b_email = v_user_email, status = 'active' WHERE id = v_couple_row.id;
      v_assigned_slot := 'partner_b';
    ELSE
      RAISE EXCEPTION 'No vacant slot available in this relationship workspace';
    END IF;
  END IF;

  UPDATE public.users SET couple_id = v_couple_row.id WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'couple_id', v_couple_row.id, 'slot', v_assigned_slot);
END;
$$;

-- ============================================================
-- 4. User Deletion Cleanup Trigger Invalidation (Audit H-4)
-- Invalidates recovery codes when a user leaves/deletes so old codes cannot claim cleared slots
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_user_deletion_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id uuid;
  v_couple_id uuid;
BEGIN
  v_couple_id := OLD.couple_id;

  IF v_couple_id IS NOT NULL THEN
    -- Look up partner from couples table
    SELECT
      CASE WHEN partner_a_id = OLD.id THEN partner_b_id ELSE partner_a_id END
    INTO v_partner_id
    FROM public.couples
    WHERE id = v_couple_id;

    -- Notify the remaining partner
    IF v_partner_id IS NOT NULL THEN
      UPDATE public.users
      SET partner_deleted_notice = TRUE
      WHERE id = v_partner_id;
    END IF;

    -- Clear the deleted user's slot, email, and invalidate old recovery key (Audit H-4)
    UPDATE public.couples
    SET
      partner_a_id          = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_id END,
      partner_b_id          = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_id END,
      partner_a_email       = CASE WHEN partner_a_id = OLD.id THEN NULL ELSE partner_a_email END,
      partner_b_email       = CASE WHEN partner_b_id = OLD.id THEN NULL ELSE partner_b_email END,
      recovery_lookup_key   = NULL,
      recovery_code_hash    = NULL,
      recovery_code_generated_at = NULL
    WHERE id = v_couple_id;

    -- Clean up couples row only if no users remain in it
    IF NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE couple_id = v_couple_id AND id != OLD.id
    ) THEN
      DELETE FROM public.couples WHERE id = v_couple_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$;


-- FILE: 20260808000002_database_constraints.sql
-- Migration: Database Integrity & Constraints (M-5, M-6, L-2)
-- Created: 2026-08-08

-- ============================================================
-- 1. Couples Status CHECK Constraint (Audit M-6)
-- Clean up any unexpected values first, then add CHECK constraint
-- ============================================================
UPDATE public.couples
SET status = 'waiting'
WHERE status NOT IN ('waiting', 'active', 'disconnected', 'archived') OR status IS NULL;

ALTER TABLE public.couples DROP CONSTRAINT IF EXISTS couples_status_check;
ALTER TABLE public.couples ADD CONSTRAINT couples_status_check
  CHECK (status IN ('waiting', 'active', 'disconnected', 'archived'));

-- ============================================================
-- 2. Calendar Events Type CHECK Constraint & Documentation (Audit M-5)
-- Document integer type meanings:
-- 0: Anniversary, 1: Birthday, 2: Date Night, 3: Holiday, 4: Custom Event
-- ============================================================
ALTER TABLE public.calendar_events DROP CONSTRAINT IF EXISTS calendar_events_type_check;
ALTER TABLE public.calendar_events ADD CONSTRAINT calendar_events_type_check
  CHECK (type >= 0 AND type <= 4);

COMMENT ON COLUMN public.calendar_events.type IS
  '0: Anniversary, 1: Birthday, 2: Date Night, 3: Holiday, 4: Custom Event';

-- ============================================================
-- 3. Users updated_at Automatic Timestamp Trigger (Audit L-2)
-- ============================================================
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_users_updated_at ON public.users;
CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
