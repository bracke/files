separate (Files_Suite.Operations)
   procedure Test_Recorded_Restore_Targets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "entry");
      Redirected : constant String := Join (Root, "redirected");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Selected : Boolean;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      procedure Restore is
      begin
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
      end Restore;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      for Background in Boolean loop
         for Scenario in 1 .. 3 loop
            for Fault in 1 .. 3 loop
               Reset_Root;
               Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
               Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", (if Scenario = 3 then "windows" else "xdg"));
               Write_Binary_File (Source, "original bytes");
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Operations.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               if Scenario = 1 then
                  Selected := Files.Model.Select_By_Name (Model, "entry");
                  Assert (Selected, "select the trash restore fixture");
                  Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
                  Await_View (Model, Settings);
                  Paths := Files.Model.Undo_From_Paths (Model);
                  Assert (Files.Model.Undo_To_Paths (Model).First_Element = To_Unbounded_String (Source),
                          "trash history retains its original destination");
               else
                  Ada.Directories.Create_Directory (Join (Root, "inbox"));
                  Write_Binary_File (Join (Root, "inbox/entry"), "pasted bytes");
                  Actions.Clear;
                  Actions.Append (Files.Paste.Resolved_Action'
                    (To_Unbounded_String (Join (Root, "inbox/entry")), To_Unbounded_String (Source), False, True));
                  Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, False);
                  Step := Complete_Operation
                    (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
                  Await_View (Model, Settings);
                  Paths := Files.Model.Undo_History (Model).Last_Element.Restore_Trash;
                  Assert (Files.Model.Undo_History (Model).Last_Element.Restore_Targets.First_Element
                          = To_Unbounded_String (Source), "paste history retains the preserved original destination");
               end if;
               Assert (Step.Status = Files.Operations.Operation_Success and then not Paths.Is_Empty,
                       "record successful trash or replacement history");
               declare
                  Sidecar : constant String :=
                    (if Scenario = 3 then Join (Ada.Directories.Containing_Directory
                       (To_String (Paths.First_Element)), "original")
                     else Join (Root, "xdg/Trash/info/" & Ada.Directories.Simple_Name
                       (To_String (Paths.First_Element)) & ".trashinfo"));
                  File : Ada.Streams.Stream_IO.File_Type;
               begin
                  if Fault = 1 then
                     if Scenario = 3 then
                        Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Sidecar);
                        String'Output (Ada.Streams.Stream_IO.Stream (File), Redirected);
                        Ada.Streams.Stream_IO.Close (File);
                     else
                        Write_Binary_File (Sidecar, "[Trash Info]" & ASCII.LF & "Path=" & Redirected & ASCII.LF);
                     end if;
                  elsif Fault = 2 then
                     Write_Binary_File (Sidecar, "");
                  else
                     Ada.Directories.Delete_File (Sidecar);
                  end if;
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Success,
                     "Undo restores to its recorded destination despite changed, truncated or missing sidecars"
                     & ": status");
                  Assert
                    (File_Has_Bytes (Source, "original bytes"),
                     "Undo restores to its recorded destination despite changed, truncated or missing sidecars"
                     & ": source restored");
                  Assert
                    (not Ada.Directories.Exists (Redirected),
                     "Undo restores to its recorded destination despite changed, truncated or missing sidecars"
                     & ": redirect target not created");
               end;
            end loop;
         end loop;
      end loop;
      Restore;
   exception
      when others => Restore; raise;
   end Test_Recorded_Restore_Targets;
