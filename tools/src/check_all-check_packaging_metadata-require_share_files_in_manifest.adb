separate (Check_All.Check_Packaging_Metadata)
   procedure Require_Share_Files_In_Manifest (Path : String) is
      --  Generated build output, not a source-tracked resource: the
      --  post-build bundler copies the i18n data tree here from the
      --  resolved dependency (it is gitignored), and release_check
      --  verifies its presence. The hand-maintained package.manifest
      --  lists only the resources that live in this repository. Skipped by
      --  its path: another directory named i18n is no generated one.
      Generated_I18N : constant String := Root & "/share/i18n/";
   begin
      for Item of Project_Tools.Files.List_Tree (Path) loop
         declare
            Full : constant String := To_String (Item);
         begin
            if not Starts_With (Full, Generated_I18N) and then Starts_With (Full, Root & "/") then
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
   end Require_Share_Files_In_Manifest;
