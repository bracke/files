with Files.Preference_Types;
with Ada.Calendar;

--  Test-only access to private subprograms of Files.Rendering, kept out of the program.
package Files.Rendering.Testing is

   --  Build a snapshot of Model with the default settings, as of the clock now.
   --
   --  @param Model Window model to snapshot.
   --  @return View snapshot for rendering.
   function Build_Snapshot
     (Model : Files.Model.Window_Model)
      return View_Snapshot;

   --  Return the palette color role that renders a color label's swatch/dot.
   --  No_Label resolves to Muted_Text_Color; it is never drawn, so the value
   --  only keeps the mapping total.
   --
   --  @param Label Color label to resolve.
   --  @return The palette role drawn in that label's color.
   function Label_Render_Color
     (Label : Files.Preference_Types.Color_Label)
      return Guikit.Draw.Render_Color;

   --  How many rows Row_Texts holds formatted.
   --
   --  @param Row_Texts A window's cache.
   --  @return The number of rows formatted for its build.
   function Formatted_Rows (Row_Texts : Row_Text_Cache) return Natural;

   --  Whether any overlay covers the view (what hides background tooltips).
   --
   --  @param Snapshot The view snapshot.
   --  @return True when an overlay is open.
   function Any_Overlay_Open (Snapshot : View_Snapshot) return Boolean;

   --  Build_Snapshot at a given time.
   --
   --  @param Model Source window model.
   --  @param Settings Settings model.
   --  @param Now The time the snapshot shows the folder at.
   --  @return The snapshot.
   function Build_Snapshot_At
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Now      : Ada.Calendar.Time)
      return View_Snapshot;

   --  Build_Snapshot as Build_Snapshot_Into builds it when the rows are
   --  kept: Rows_From's rows are taken and only their selected flags set,
   --  at Rows_From's time.
   --
   --  @param Model Source window model.
   --  @param Settings Settings model.
   --  @param Rows_From A snapshot of this model whose rows are still right
   --    but for which are selected (the model's Rows_Revision has not moved
   --    since it was built).
   --  @return The snapshot.
   function Build_Snapshot_Keeping_Rows
     (Model     : Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Rows_From : View_Snapshot)
      return View_Snapshot;

end Files.Rendering.Testing;
