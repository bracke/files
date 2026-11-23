with Files.Interaction.Testing;
with Files.Interaction;
with Files.Overlays.Settings_Form;
separate (Files_Suite.Settings)
   --  A held arrow stepping a number in the settings pane: each repeat's
   --  step is in force at once, but the file is written (and the folder read
   --  again) once, when the key is let go -- not once per repeat. The window
   --  layer says which keys are repeats and saves once one is let go; here
   --  that is done by hand.
   procedure Test_Held_Key_Saves_Once (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Settings_Panel.Field_Kind;
      Path     : constant String := Join (Root, "held.conf");
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean := False;

      function Written return Boolean is (Ada.Directories.Exists (Path));
   begin
      Reset_Root;
      Files.Overlays.Settings_Form.Begin_Edit (Model, Settings);
      Sections :
      for Section in 1 .. Files.Model.Settings_Pane.Section_Count (Model) loop
         Files.Model.Settings_Pane.Set_Active_Section (Model, Section);
         for Step in 1 .. 200 loop
            if Files.Model.Settings_Pane.Focused_Kind (Model) = Guikit.Settings_Panel.Number then
               Found := True;
               exit Sections;
            end if;
            Files.Model.Settings_Pane.Move_Focus (Model, 1);
         end loop;
      end loop Sections;
      Assert (Found, "the pane has a number field");
      declare
         Key    : constant String := Files.Model.Settings_Pane.Focused_Key (Model);
         Before : constant String := Files.Model.Settings_Pane.Focused_Value (Model);
      begin
         Assert (not Written, "no settings file yet");
         --  Three repeats of a held Right.
         for Repeat in 1 .. 3 loop
            Files.Interaction.Handle_Key
              (Model, Settings, Path, Guikit.Input.Key_Right, Result => Result, Repeated => True);
         end loop;
         Assert (Files.Model.Settings_Pane.Focused_Value (Model) /= Before, Key & ": the held key stepped the value");
         Assert
           (not Files.Settings.Same_Content (Settings, Files.Settings.Default_Settings),
            Key & ": each step is in force at once");
         Assert (not Written, Key & ": nothing is written while the key is held");
         Assert (Files.Model.Settings_Pane.Save_Is_Deferred (Model), "the save waits for the key's release");

         --  Let go: the window layer saves what was deferred, once.
         Assert (Files.Model.Settings_Pane.Take_Deferred_Save (Model), "the deferred save is taken");
         Files.Interaction.Testing.Execute_Command
           (Model, Settings, Path, Files.Commands.Save_Settings_Command, Result => Result);
         Assert (Written, Key & ": the value is written once the key is let go");
         declare
            Loaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Storage.Load_File (Path);
         begin
            Assert (Loaded.Success, "the written file loads");
            for Setting in Files.Settings.Scalar_Setting loop
               Files_Suite.Support.Assert_Equal
                 (Files.Settings.Testing.Scalar_Text (Loaded.Settings, Setting),
                  Files.Settings.Testing.Scalar_Text (Settings, Setting),
                  Key & ": the file holds the settings in force: " & Setting'Image);
            end loop;
         end;
         Assert (not Files.Model.Settings_Pane.Save_Is_Deferred (Model), "nothing is left to save");
      end;
   end Test_Held_Key_Saves_Once;
