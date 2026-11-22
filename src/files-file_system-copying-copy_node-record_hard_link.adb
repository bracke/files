separate (Files.File_System.Copying.Copy_Node)
procedure Record_Hard_Link is
begin
   if Track_Hard_Link then
      --  The source as copied, checked once more against change during
      --  the copy (these revisions leave out the change time, which the
      --  link count moves). A regular file was hashed as it was copied,
      --  and the destination holds exactly those bytes; a link's target
      --  is short and read on both sides.
      declare
         From_Copy : constant Boolean := Length (Copied_Bytes_Digest) > 0;
      begin
         Source_Content_Digest :=
           (if From_Copy then Copied_Bytes_Digest else To_Unbounded_String (Content_Digest (Source_Path, Walk)));
         if Files.File_Identities.Revision (Source_Path, False) /= To_String (Source_Revision)
           or else (From_Copy and then Content_Digest (Source_Path, Walk) /= To_String (Source_Content_Digest))
           or else (not From_Copy
                    and then Content_Digest (Destination_Path, Walk) /= To_String (Source_Content_Digest))
         then
            raise Ada.Directories.Use_Error;
         end if;
      end;
      declare
         Identity : constant String := Files.File_Identities.Token (Destination_Path);
         Destination_Revision : constant String :=
           Files.File_Identities.Revision (Destination_Path, False);
      begin
         if Identity = "" or else Destination_Revision = "" then
            raise Ada.Directories.Use_Error;
         end if;
         Copied_Files.Insert
           (To_String (Source_Identity),
            (Path                 => To_Unbounded_String (Destination_Path),
             Identity             => To_Unbounded_String (Identity),
             Source_Revision      => Source_Revision,
             Destination_Revision => To_Unbounded_String (Destination_Revision),
             Content_Digest       => Source_Content_Digest));
      end;
   end if;
end Record_Hard_Link;
