with Files.Rendering.Geometry;

package body Files.Rendering.Testing is

   function Label_Render_Color
     (Label : Files.Types.Color_Label)
      return Guikit.Draw.Render_Color
     renames Files.Rendering.Geometry.Label_Render_Color;

   function Any_Overlay_Open (Snapshot : View_Snapshot) return Boolean
     renames Files.Rendering.Geometry.Any_Overlay_Open;

   function Context_Menu_Row_Top
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
     renames Files.Rendering.Geometry.Context_Menu_Row_Top;

   function Context_Menu_Row_Left
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
     renames Files.Rendering.Geometry.Context_Menu_Row_Left;

   function Context_Menu_Row_Width
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
     renames Files.Rendering.Geometry.Context_Menu_Row_Width;

   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout
     renames Files.Rendering.Geometry.Calculate_Paste_Progress_Layout;

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
         Result.Items := Rows_From.Items;
         Build_Snapshot_Into (Result, Model, Settings, Rows_From.Now, Keep_Rows => True);
      end return;
   end Build_Snapshot_Keeping_Rows;

end Files.Rendering.Testing;
