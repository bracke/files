with Files.Model;
with Files.Operations;
with Files.Settings;

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
      Kind : Operation_Kind) return Files.Operations.Operation_Result;

   --  @param Model Window owning a helper session.
   --  @param Settings Current settings used when refreshing after completion.
   --  @return Pending success, or the completed operation result.
   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operations.Operation_Result;

   --  @param Directory Private request/result directory passed to a helper.
   procedure Run_Helper (Directory : String);
end Files.Operation_Jobs;
