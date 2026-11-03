with Files.Settings.Testing;
separate (Files_Suite.Rendering)
   --  The window keeps a snapshot's rows while Same_Row_Settings holds
   --  (Snapshot_Policy.Patch_Rows). That is right only if every setting a row
   --  shows is in it: so change each setting to every value it accepts (and
   --  each mapping, label and favorite), and wherever the rows would be kept,
   --  the patched snapshot must be the rebuilt one.
   procedure Test_Row_Settings_Cover_The_Rows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base       : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model      : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      function "+" (Text : String) return Files.Types.UString renames To_Unbounded_String;
      type Text_List is array (Positive range <>) of Files.Types.UString;
      Candidates : constant Text_List :=
        [+"true", +"false", +"small", +"large", +"details", +"name", +"size", +"modified", +"type",
         +"created", +"light", +"dark", +"system", +"none", +"label", +"kind", +"10", +"24", +"40", +"400",
         +"Adwaita", +"hicolor", +"size,name,modified,filetype,created,permissions"];
      Changes     : Natural := 0;
      Row_Changes : Natural := 0;

      procedure Check (Step : String; Changed : Files.Settings.Settings_Model) is
         Before : aliased constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Base);
      begin
         Changes := Changes + 1;
         if Files.Settings.Same_Row_Settings (Changed, Files.Settings.Snapshot_Settings_Key_Of (Base)) then
            Assert
              (Files.Rendering.Build_Snapshot (Model, Changed, Rows_From => Before'Access)
               = Files.Rendering.Build_Snapshot (Model, Changed),
               Step & ": a change the rows are kept across leaves them as a rebuild draws them");
         else
            Row_Changes := Row_Changes + 1;
         end if;
      end Check;

      First_Path : constant String := To_String (Files.Model.Visible_Item (Model, 1).Full_Path);
   begin
      for View in Files.Types.View_Mode loop
         Files.Model.Set_View_Mode (Model, View);
         for Setting in Files.Settings.Scalar_Setting loop
            for Text of Candidates loop
               declare
                  Changed : Files.Settings.Settings_Model := Base;
                  Error   : Files.Types.UString;
               begin
                  Files.Settings.Testing.Set_Scalar (Changed, Setting, To_String (Text), Error);
                  if Length (Error) = 0
                    and then Files.Settings.Testing.Scalar_Text (Changed, Setting)
                      /= Files.Settings.Testing.Scalar_Text (Base, Setting)
                  then
                     Check (Setting'Image & " = " & To_String (Text), Changed);
                  end if;
               end;
            end loop;
         end loop;
         declare
            Changed : Files.Settings.Settings_Model := Base;
         begin
            Files.Settings.Testing.Add_Extension_Mapping (Changed, "txt", "application/x-row-test");
            Check ("an extension mapping", Changed);
         end;
         declare
            Changed : Files.Settings.Settings_Model := Base;
         begin
            Files.Settings.Testing.Add_Icon_Mapping (Changed, "text/plain", "folder");
            Check ("an icon mapping", Changed);
         end;
         declare
            Changed : Files.Settings.Settings_Model := Base;
         begin
            Files.Settings.Set_Label (Changed, First_Path, Files.Types.Red);
            Check ("a label", Changed);
         end;
         declare
            Changed : Files.Settings.Settings_Model := Base;
         begin
            Changed.Favorite_Paths.Append (To_Unbounded_String (First_Path));
            Check ("a favorite", Changed);
         end;
      end loop;
      Assert (Changes > 50, "the settings were changed many ways:" & Changes'Image);
      Assert (Row_Changes > 0, "some changes end the row patch:" & Row_Changes'Image);
   end Test_Row_Settings_Cover_The_Rows;
