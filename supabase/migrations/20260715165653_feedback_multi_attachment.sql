alter table "public"."feedback" drop column "attachment_path";

alter table "public"."feedback" add column "attachment_paths" text[];


