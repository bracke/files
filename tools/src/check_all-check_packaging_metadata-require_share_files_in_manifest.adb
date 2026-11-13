separate (Check_All.Check_Packaging_Metadata)
   procedure Require_Share_Files_In_Manifest (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Full = Root & "/share/i18n" then
               --  Generated build output, not a source-tracked resource: the
               --  post-build bundler copies the i18n data tree here from the
               --  resolved dependency (it is gitignored), and release_check
               --  verifies its presence. The hand-maintained package.manifest
               --  lists only the resources that live in this repository.
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               Require_Share_Files_In_Manifest (Full);
            elsif Starts_With (Full, Root & "/") then
               declare
                  Relative : constant String :=
                    Full (Full'First + Root'Length + 1 .. Full'Last);
               begin
                  Require_Manifest_Entry
                    (Relative,
                     "files package manifest must include share resource: " & Relative);
               end;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Require_Share_Files_In_Manifest;
