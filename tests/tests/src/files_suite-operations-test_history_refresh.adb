separate (Files_Suite.Operations)
   procedure Test_History_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source_Dir : constant String := Join (Root, "history-source");
      Dest_Dir : constant String := Join (Root, "history-dest");
      Source_A : constant String := Join (Source_Dir, "a.txt");
      Source_B : constant String := Join (Source_Dir, "b.txt");
      Dest_A : constant String := Join (Dest_Dir, "a.txt");
      Dest_B : constant String := Join (Dest_Dir, "b.txt");
   begin
      for Recent in Boolean loop
         for Background in Boolean loop
            for Blocked in Boolean loop
               Reset_Root;
               declare
                  Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
                  Model : Files.Model.Window_Model;
                  Load : Files.File_System.Directory_Load_Result;
                  Step : Files.Operations.Operation_Result;
                  Sources, Destinations : Files.Types.String_Vectors.Vector;

                  function Listed (Path : String) return Boolean is
                  begin
                     for Index in 1 .. Files.Model.Visible_Count (Model) loop
                        if Files.Model.Visible_Item (Model, Index).Full_Path = To_Unbounded_String (Path) then
                           return True;
                        end if;
                     end loop;
                     return False;
                  end Listed;

                  procedure Check_Refresh (Error_Key : String) is
                     Applied : Boolean := False;
                  begin
                     if Background then
                        Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                                "the history action schedules a background refresh");
                        for Attempt in Files_Suite.Support.Polling loop
                           Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
                           exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
                        end loop;
                        Assert (Applied and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                                "Undo or Redo's own refresh applies without a fallback poll or manual reload");
                     else
                        Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                                "headless history actions still reload synchronously");
                     end if;
                     Files_Suite.Support.Assert_Equal
                       (Files.Model.Last_Error_Key (Model),
                        Error_Key,
                        "refresh preserves the history action's final success or failure state");
                     Files_Suite.Support.Assert_Equal
                       (Files.Model.In_Recent_View (Model),
                        Recent,
                        "history refresh preserves the active view");
                  end Check_Refresh;
               begin
                  Ada.Directories.Create_Path (Source_Dir);
                  Ada.Directories.Create_Path (Dest_Dir);
                  Write_Binary_File (Dest_A, "original a");
                  Write_Binary_File (Dest_B, "original b");
                  if Blocked then
                     Write_Binary_File (Source_B, "unrelated source collision");
                  end if;
                  Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
                  Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
                  if Recent then
                     Files.Settings.Note_Recent (Settings, Source_A);
                     Files.Settings.Note_Recent (Settings, Source_B);
                     Step := Files.Operations.Navigate_Recent (Model, Settings);
                  end if;
                  Sources.Append (To_Unbounded_String (Source_A));
                  Sources.Append (To_Unbounded_String (Source_B));
                  Destinations.Append (To_Unbounded_String (Dest_A));
                  Destinations.Append (To_Unbounded_String (Dest_B));
                  Files.Model.Record_Undo (Model, Files.Model.Undo_Move, Destinations, Sources);
                  Files.Model.Set_Background_Transfers (Model, Background);
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  if Blocked then
                     Files_Suite.Support.Assert_Equal
                       (Step.Status,
                        Files.Operations.Operation_Failed,
                        "the blocked Undo reports partial failure");
                     Check_Refresh ("error.undo.failed");
                     Assert ((if Recent then Listed (Source_A) and then Listed (Source_B)
                              else not Listed (Dest_A) and then Listed (Dest_B)),
                             "a partial Undo refresh shows its completed mutation");
                     Assert (File_Has_Bytes (Source_B, "unrelated source collision"),
                             "the blocked Undo preserves the occupying source");
                     Ada.Directories.Delete_File (Source_B);
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  end if;
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Success,
                     "the full Undo succeeds");
                  Check_Refresh ("");
                  Assert ((if Recent then Listed (Source_A) and then Listed (Source_B)
                           else Files.Model.Item_Count (Model) = 0),
                          "Undo immediately relists restored Recent paths or empties the original directory");
                  if Blocked then
                     Write_Binary_File (Dest_B, "unrelated destination collision");
                  end if;
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
                  if Blocked then
                     Files_Suite.Support.Assert_Equal
                       (Step.Status,
                        Files.Operations.Operation_Failed,
                        "the blocked Redo reports partial failure");
                     Check_Refresh ("error.undo.failed");
                     Assert ((if Recent then not Listed (Source_A) and then Listed (Source_B)
                              else Listed (Dest_A) and then Listed (Dest_B)),
                             "a partial Redo refresh shows its completed mutation");
                     Assert (File_Has_Bytes (Dest_B, "unrelated destination collision"),
                             "the blocked Redo preserves the occupying destination");
                     Ada.Directories.Delete_File (Dest_B);
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
                  end if;
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Success,
                     "the full Redo succeeds");
                  Check_Refresh ("");
                  Assert ((if Recent then Files.Model.Item_Count (Model) = 0
                           else Listed (Dest_A) and then Listed (Dest_B)),
                          "Redo removes moved Recent paths or relists the full destination directory");
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Success,
                     "Undo works again after the refreshed Redo");
                  Check_Refresh ("");
                  Assert (File_Has_Bytes (Source_A, "original a") and then File_Has_Bytes (Source_B, "original b"),
                          "the refreshed history cycle preserves the original bytes");
               end;
            end loop;
         end loop;
      end loop;
   end Test_History_Refresh;
