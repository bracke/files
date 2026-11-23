with Files.File_System_Types;
with Files.Model;
with Files.Operation_Results;
with Files.Settings;
private with Files.Items;
private with Files.Types;
private with Files.UI_Types;
private with Ada.Streams;

--  Long operations execute in a helper using an isolated model.
package Files.Job_Drivers.Operation is
   type Operation_Kind is
     (Duplicate, Compress_Zip, Compress_Seven_Zip, Extract, Search_Names, Search_Contents,
      Trash, Delete_Permanently, Restore, Empty_Trash, Undo, Redo);

   --  @param Model Window to arm with a background operation and modal progress.
   --  @param Settings Immutable settings snapshot.
   --  @param Kind Operation to execute.
   --  @return Immediate launch result; completion is collected by Advance.
   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Kind : Operation_Kind) return Files.Operation_Results.Operation_Result;

   --  @param Model Window owning a helper session.
   --  @param Settings Current settings used when refreshing after completion.
   --  @return Pending success, or the completed operation result.
   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operation_Results.Operation_Result;

private
   --  A test seam (Files.Job_Drivers.Operation.Testing): when set, Advance calls it
   --  once the journal is merged and the undo recovered. It raises, so
   --  Advance fails as if its view work had: the failure is the test's own.
   type Merge_Hook is access procedure (Model : in out Files.Model.Window_Model);
   After_Merge : Merge_Hook := null;

   --  Normal operations run against an absolute directory. The Recent view is
   --  synthetic and is represented by an empty root.
   function Request_Path_Is_Consistent
     (Root   : String;
      Recent : Boolean) return Boolean;

   --  The wire records a job and its helper (Files.Job_Drivers.Operation.Helper)
   --  exchange: the window's request, and what the helper did.
   type Request is record
      Kind     : Operation_Kind;
      Root     : Files.Types.UString;
      Recent   : Boolean;
      Query    : Files.Types.UString;
      --  The scope whose results the window shows (Query found them), or
      --  Filter_Here when it shows a folder's listing: the helper's model
      --  shows them too, so its reload searches again as the window's own
      --  would (Operations' Reload_Current_Directory).
      Searched : Files.UI_Types.Search_Scope := Files.UI_Types.Filter_Here;
      Selected : Files.Items.Item_Vectors.Vector;
      Settings : Files.Settings.Settings_Model;
      Context_Revision : Natural;
      View_Incarnation : Natural;
      --  For an Undo, the Sequence of the entry it takes (the window's
      --  newest); 0 otherwise.
      Undo_Sequence    : Natural;
   end record;

   type Outcome is record
      Kind      : Operation_Kind;
      Recent    : Boolean := False;
      Result    : Files.Operation_Results.Operation_Result;
      Items     : Files.Items.Item_Vectors.Vector;
      --  The item the helper's model selected after the operation: its
      --  name, and its full path, which is what the window selects by
      --  (search results may list two items of one name).
      Selection : Files.Types.UString;
      Selection_Path : Files.Types.UString;
      --  Whose search results Items are (Request.Searched), or Filter_Here
      --  for a folder's listing.
      Searched  : Files.UI_Types.Search_Scope := Files.UI_Types.Filter_Here;
      Visible_Error : Files.Types.UString;
      Signature : Files.File_System_Types.Directory_Signature;
      --  The renames, moves and removals the helper made (Note_Path_Move),
      --  for the window's labels and favorites to follow.
      Moves     : Files.Types.Path_Move_Vectors.Vector;
   end record;

   --  @param Path The request file.
   --  @return The request, validated.
   function Read_Request (Path : String) return Request;

   --  @param Stream Where the helper writes its result.
   --  @param Done What it did.
   procedure Write_Outcome
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done   : Outcome);
end Files.Job_Drivers.Operation;
