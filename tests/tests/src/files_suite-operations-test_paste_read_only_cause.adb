separate (Files_Suite.Operations)
   procedure Test_Paste_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Environment : Files_Suite.Support.Environment_Guard;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Sources : Files.Types.String_Vectors.Vector;
      Source : constant String := Join (Root, "source.txt");
      Locked : constant String := Join (Root, "locked");
   begin
      Environment.Save ("XDG_DATA_HOME");
      for Background in Boolean loop
         Reset_Root;
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
         Write_Binary_File (Source, "source bytes");
         Ada.Directories.Create_Directory (Locked);
         Load := Files.File_System.Load_Directory (Locked, Settings);
         Files.Model.Initialize (Model, Locked, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         if not Lock_Directory (Locked) then
            Unlock_Directory (Locked);
            Files_Suite.Support.Skip
              ("Test_Paste_Read_Only_Cause", "a read-only directory does not refuse writes here");
            return;
         end if;
         Sources.Clear;
         Sources.Append (To_Unbounded_String (Source));
         Step := Files.Operations.Begin_Paste (Model, Settings, Sources, Files.File_System.Drop_Copy, False);
         Step := Complete_Operation (Model, Settings, Step);
         Await_View (Model, Settings);
         Unlock_Directory (Locked);
         Assert (Step.Status = Files.Operations.Operation_Failed, "a paste into a read-only folder fails");
         Assert_Equal
           (To_String (Step.Error_Key), "error.io.denied",
            (if Background then "a helper's" else "a foreground") & " refused paste says permission was denied");
         Assert (not Ada.Directories.Exists (Join (Locked, "source.txt"))
                 and then File_Has_Bytes (Source, "source bytes"),
                 "the refused paste adds nothing and keeps its source");
      end loop;
   exception
      when others =>
         Unlock_Directory (Locked);
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Paste_Read_Only_Cause;
