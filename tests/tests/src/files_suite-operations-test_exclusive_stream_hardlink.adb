separate (Files_Suite.Operations)
   procedure Test_Exclusive_Stream_Hardlink (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reset_Root;
      declare
         Victim : constant String := Join (Root, "exclusive-stream-victim");
         Alias  : constant String := Join (Root, "exclusive-stream-alias");
         Output : Files.Exclusive_Streams.Output_Stream;
         Refused : Boolean := False;
         Linked  : Boolean := False;
      begin
         Write_Binary_File (Victim, "unchanged");
         Linked := Hostkit.Fs.Create_Hard_Link (Victim, Alias);
         if Linked then
            begin
               Files.Exclusive_Streams.Create (Output, Alias);
            exception
               when Ada.IO_Exceptions.Use_Error => Refused := True;
            end;
            Files.Exclusive_Streams.Close_Safely (Output);
            Assert
              (Refused
               and then Project_Tools.Files.Read_Raw_File (Victim) = "unchanged",
               "exclusive transport streams refuse hardlinks without truncating their target");
            Ada.Directories.Delete_File (Alias);
         else
            Files_Suite.Support.Link_Not_Made ("Test_Exclusive_Stream_Hardlink", Files_Suite.Support.Hard_Link);
         end if;
         Ada.Directories.Delete_File (Victim);
      exception
         when others =>
            Files.Exclusive_Streams.Close_Safely (Output);
            if Linked and then Ada.Directories.Exists (Alias) then
               Ada.Directories.Delete_File (Alias);
            end if;
            if Ada.Directories.Exists (Victim) then
               Ada.Directories.Delete_File (Victim);
            end if;
            raise;
      end;
   end Test_Exclusive_Stream_Hardlink;
