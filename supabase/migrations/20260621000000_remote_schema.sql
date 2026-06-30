


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
    ADD CONSTRAINT "love_notes_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id");



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































