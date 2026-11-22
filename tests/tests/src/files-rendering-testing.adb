with Files.Rendering.Geometry;
with Files.Rendering.Labels;

package body Files.Rendering.Testing is

   function Formatted_Rows (Row_Texts : Row_Text_Cache) return Natural is
     (Natural (Row_Texts.Rows.Length));

   function Build_Snapshot
     (Model : Files.Model.Window_Model)
      return View_Snapshot is
     (Build_Snapshot (Model, Files.Settings.Default_Settings));

   function Label_Render_Color
     (Label : Files.Preference_Types.Color_Label)
      return Guikit.Draw.Render_Color
     renames Files.Rendering.Labels.Label_Render_Color;

   function Any_Overlay_Open (Snapshot : View_Snapshot) return Boolean
     renames Files.Rendering.Geometry.Any_Overlay_Open;

   function Build_Snapshot_At
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Now      : Ada.Calendar.Time)
      return View_Snapshot is
   begin
      return Result : View_Snapshot do
         Build_Snapshot_Into (Result, Model, Settings, Now);
      end return;
   end Build_Snapshot_At;

   function Build_Snapshot_Keeping_Rows
     (Model     : Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Rows_From : View_Snapshot)
      return View_Snapshot is
   begin
      return Result : View_Snapshot do
         Copy_Rows (Result, Rows_From);
         Build_Snapshot_Into (Result, Model, Settings, Rows_From.Now, Keep_Rows => True);
      end return;
   end Build_Snapshot_Keeping_Rows;

end Files.Rendering.Testing;
