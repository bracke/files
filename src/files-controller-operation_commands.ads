with Files.Operations.Archives;
with Files.UI_Types;
with Files.Model;
with Files.Operation_Results;
with Files.Operations;
with Files.Settings;

--  The selection, trash, search and history commands a window can run in a
--  helper job: there when the window runs them in the background
--  (Files.Model.Background_Transfers), otherwise in process
--  (Files.Operations). The one unit that sees both: Files.Operations never
--  starts a job, and a helper job (Files.Job_Drivers.Operation.Helper) runs the
--  in-process work. Each asks the command's refusal checks before it starts
--  a job, as the in-process command does before it runs.
package Files.Controller.Operation_Commands is

   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory reloads.
   --  @return Structured operation result.
   function Delete_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Files.Operation_Results.Operation_Result;

   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory reloads.
   --  @return Structured operation result.
   function Delete_Selected_Permanently
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Files.Operation_Results.Operation_Result;

   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory reloads.
   --  @return Structured operation result.
   function Restore_Selected_From_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Files.Operation_Results.Operation_Result;

   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory reloads.
   --  @return Structured operation result.
   function Empty_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Files.Operation_Results.Operation_Result;

   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory reloads.
   --  @return Structured operation result.
   function Duplicate_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Files.Operation_Results.Operation_Result;

   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory reloads.
   --  @param Format Archive container format to produce.
   --  @return Structured operation result.
   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Files.Operations.Archives.Archive_Format)
      return Files.Operation_Results.Operation_Result;

   --  @param Model Window model to update.
   --  @param Settings Settings model used for directory reloads.
   --  @return Structured operation result.
   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Files.Operation_Results.Operation_Result;

   --  @param Model Window model holding the query and current folder.
   --  @param Settings Settings model used for directory classification.
   --  @param Scope Search by name or by content.
   --  @return Structured operation result.
   function Run_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Scope    : Files.UI_Types.Tree_Search_Scope)
      return Files.Operation_Results.Operation_Result;

   --  Undo the newest action. A helper replays only what its journal hands
   --  it, so an entry too large for the journal is undone in process.
   --
   --  @param Model Window model carrying the undo history.
   --  @param Settings Settings model used for directory reloads.
   --  @return Structured operation result.
   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Files.Operation_Results.Operation_Result;

   --  Redo the newest undone action, like Undo_Last.
   --
   --  @param Model Window model carrying the redo history.
   --  @param Settings Settings model used for directory reloads.
   --  @return Structured operation result.
   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Files.Operation_Results.Operation_Result;

end Files.Controller.Operation_Commands;
