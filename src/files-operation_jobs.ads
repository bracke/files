with Files.Model;
with Files.Operation_Results;
with Files.Settings;
private with Files.File_System;
private with Files.Items;
private with Files.Types;
private with Ada.Streams;

--  Long operations execute in a helper using an isolated model.
package Files.Operation_Jobs is
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
   --  A test seam (Files.Operation_Jobs.Testing): when set, Advance calls it
   --  once the journal is merged and the undo recovered, then fails as if
   --  its view work had raised.
   type Merge_Hook is access procedure (Model : in out Files.Model.Window_Model);
   After_Merge : Merge_Hook := null;

   --  Normal operations run against an absolute directory. The Recent view is
   --  synthetic and is represented by an empty root.
   function Request_Path_Is_Consistent
     (Root   : String;
      Recent : Boolean) return Boolean;

   --  The wire records a job and its helper (Files.Operation_Jobs.Helper)
   --  exchange: the window's request, and what the helper did.
   type Request is record
      Kind     : Operation_Kind;
      Root     : Files.Types.UString;
      Recent   : Boolean;
      Query    : Files.Types.UString;
      Selected : Files.Items.Item_Vectors.Vector;
      Settings : Files.Settings.Settings_Model;
      Context_Revision : Natural;
      View_Incarnation : Natural;
   end record;

   type Outcome is record
      Kind      : Operation_Kind;
      Recent    : Boolean := False;
      Result    : Files.Operation_Results.Operation_Result;
      Items     : Files.Items.Item_Vectors.Vector;
      Selection : Files.Types.UString;
      Visible_Error : Files.Types.UString;
      Signature : Files.File_System.Directory_Signature;
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
end Files.Operation_Jobs;
