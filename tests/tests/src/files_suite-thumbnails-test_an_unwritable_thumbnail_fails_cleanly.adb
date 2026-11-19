with Files.File_System.Thumbnails;
with Files_Suite.Support.File_Size_Limits;
separate (Files_Suite.Thumbnails)
   --  A stand-in thumbnail written to a disk that will not take it fails as a
   --  thumbnail failure: nothing raises out of the generator, and neither the
   --  temporary reserved for the decoders nor the stand-in's is left in the
   --  cache. A file-size limit stands in for the full disk.
   procedure Test_An_Unwritable_Thumbnail_Fails_Cleanly (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source  : constant String := Join (Root, "too-big.png");
      Cache   : constant String := Join (Root, "full-cache");
      Full    : Files_Suite.Support.File_Size_Limits.Cap;
      Result  : Files.File_System.Thumbnails.Thumbnail_Result;
      Escaped : Boolean := False;
   begin
      Reset_Root;
      Write_Binary_File (Source, Minimal_Png_Header (48, 32));
      if not Files_Suite.Support.File_Size_Limits.Lower (Full, 2_048) then
         Files_Suite.Support.Skip ("Test_An_Unwritable_Thumbnail_Fails_Cleanly", "this host has no file-size limit");
         return;
      end if;
      begin
         Result := Files.File_System.Thumbnails.Generate_Thumbnail (Source, Cache, Size => 128);
      exception
         when others =>
            Escaped := True;
      end;
      Files_Suite.Support.File_Size_Limits.Lift (Full);
      Assert (not Escaped, "a thumbnail the disk will not take does not raise out of the generator");
      Assert (Result.Status = Files.File_System.Thumbnails.Thumbnail_Failed, "it is a thumbnail failure");
      declare
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
         Left   : Natural := 0;
      begin
         Ada.Directories.Start_Search (Search, Cache, "*", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Left := Left + 1;
         end loop;
         Ada.Directories.End_Search (Search);
         Assert (Left = 0, "and leaves nothing in the cache:" & Left'Image & " file(s) left");
      end;
   end Test_An_Unwritable_Thumbnail_Fails_Cleanly;
