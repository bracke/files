with Files.Overlays;
with Files.Model.Command_Palette;
with Files_Suite.Support.Models;
separate (Files_Suite.Interaction)
   --  Shortcuts are the process's: rebound in one window, they are the
   --  keys every window's palette must show. A window that adopts the other
   --  window's settings lists its open palette again, so a row shows the new
   --  keys rather than the ones it was listed with.
   procedure Test_Adopted_Shortcut_Relists_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Rebound  : constant String :=
        Files.Commands.Shortcut_Display_Text (Files.Commands.Parse_Shortcut ("control+shift+9"));

      --  Whether the palette, drawn now, shows Rebound anywhere.
      function Shows_Rebound return Boolean is
         Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text  : Guikit.Draw.Text_Command_Vectors.Vector;
         Icons : Guikit.Draw.Icon_Command_Vectors.Vector;
         Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      begin
         Files.Overlays.Build_Palette_Frame
           (Model => Model, Region => (X => 0, Y => 0, Width => 600, Height => 500,
                     Clip_Width => 600, Clip_Height => 500, Line_Height => 20), Focused => True,
            Rectangles => Rects, Text => Text, Icons => Icons, Accessibility => Nodes);
         for Command of Text loop
            if Ada.Strings.Unbounded.To_String (Command.Text) = Rebound then
               return True;
            end if;
         end loop;
         return False;
      end Shows_Rebound;
   begin
      Files.Model.Command_Palette.Open (Model);
      Files.Model.Command_Palette.Set_Query (Model, "hidden");
      Assert (not Shows_Rebound, "the palette shows the hidden-files toggle's own keys first");

      --  Another window rebinds it: nothing in this window's model moved.
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Toggle_Hidden_Files_Command, Files.Commands.Parse_Shortcut ("control+shift+9"));
      Files.Interaction.Adopt_Shared_Settings (Model, Settings, Shared => Settings);
      Assert (Shows_Rebound, "after adopting the shared settings the palette shows the new keys");
      Files.Commands.Reset_Shortcut_Overrides;
   exception
      when others =>
         Files.Commands.Reset_Shortcut_Overrides;
         raise;
   end Test_Adopted_Shortcut_Relists_Palette;
