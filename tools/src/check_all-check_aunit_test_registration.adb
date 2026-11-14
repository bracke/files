separate (Check_All)
   procedure Check_AUnit_Test_Registration is
   begin
      Project_Tools.AUnit_Checks.Require_Registered_Test_Packages
        (Test_Dir         => Root & "/tests/tests/src",
         Spec_Pattern     => "files_suite-*.ads",
         Suite_Path       => Root & "/tests/tests/src/files_suite.adb",
         Suite_Add_Prefix => "Result.Add_Test (",
         Suite_Add_Suffix => ".Suite)",
         Section_Marker   => "function Suite");
      for Found of Project_Tools.Files.List_Tree (Root & "/tests/tests/src", "files_suite-*.adb", Generated_Directories)
      loop
         declare
            Path    : constant String := To_String (Found);
            Content : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
            Prefix  : constant String := ASCII.LF & "   procedure Test_";
            From    : Natural := Content'First;
         begin
            if Ada.Strings.Fixed.Index (Content, "procedure Register_Tests") > 0 then
               loop
                  declare
                     At_Decl : constant Natural := Ada.Strings.Fixed.Index (Content (From .. Content'Last), Prefix);
                  begin
                     exit when At_Decl = 0;
                     declare
                        Name_First : constant Positive := At_Decl + Prefix'Length - 5;
                        Name_Last  : Natural := Name_First;
                     begin
                        while Name_Last < Content'Last
                          and then Content (Name_Last + 1) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_'
                        loop
                           Name_Last := Name_Last + 1;
                        end loop;
                        if Ada.Strings.Fixed.Index (Content, Content (Name_First .. Name_Last) & "'Access") = 0 then
                           Put_Line
                             (Standard_Error,
                              Path & ": " & Content (Name_First .. Name_Last) & " is declared but never registered");
                           Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                           raise Program_Error;
                        end if;
                        From := Name_Last + 1;
                     end;
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Check_AUnit_Test_Registration;
