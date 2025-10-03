-- Storage bucket policies for AccountsPictures
-- Create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('accounts-pictures', 'AccountsPictures', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for AccountsPictures bucket
CREATE POLICY "Users can upload their own files"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'accounts-pictures'
);

CREATE POLICY "Users can view their own pictures"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'accounts-pictures'
  AND (auth.jwt() ->> 'sub')::text = split_part(name, '/', 1)
);

CREATE POLICY "Users can update their own pictures"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'accounts-pictures'
  AND (auth.jwt() ->> 'sub')::text = split_part(name, '/', 1)
);

CREATE POLICY "Users can delete their own pictures"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'accounts-pictures'
  AND (auth.jwt() ->> 'sub')::text = split_part(name, '/', 1)
);
