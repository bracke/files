with Ada.Strings.Unbounded;

package body Files.Operations.Testing is

   use Ada.Strings.Unbounded;

   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle
   is
      State : Open_Action_Lifecycle_State := Open_Action_Not_Started;
   begin
      if Result.Status = Operation_Action_Executed then
         --  "Completed" means we saw it finish, which we only do when we waited for
         --  it. A detached launch is started and let go, so the honest state is
         --  Spawned: the process is running, and its outcome is not ours to know.
         State :=
           (if Result.Execution.Exit_Status_Known
            then Open_Action_Completed
            else Open_Action_Spawned);
      elsif Result.Status = Operation_Failed and then Result.Execution.Attempted then
         State := Open_Action_Failed;
      elsif Result.Status = Operation_Failed
        and then not Result.Execution.Executable_Found
        and then To_String (Result.Action.Executable) /= ""
      then
         State := Open_Action_Preflight_Failed;
      elsif Result.Execution.Attempted then
         State := Open_Action_Spawned;
      end if;

      return
        (State             => State,
         Executable        => Result.Action.Executable,
         Argument_Count    => Natural (Result.Action.Arguments.Length),
         Uses_Shell        => Result.Action.Use_Shell,
         Exit_Status_Known => Result.Execution.Exit_Status_Known,
         Exit_Status       => Result.Execution.Exit_Status,
         Cancellation_Available => False);
   end Open_Action_Lifecycle_Of;

   function Detected_Terminal return String
     renames Files.Operations.Detected_Terminal;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean
     renames Files.Operations.Content_Matches;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
     renames Files.Operations.Prepare_Open_Selected_Action;

   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Set_Permissions_For;

   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Provenance  : Undo_Provenance := (others => <>)) return Boolean
     renames Files.Operations.Try_Record_Undo;

   procedure Settle_History (Model : in out Files.Model.Window_Model)
     renames Files.Operations.Settle_History;

   --  What Count_Undo_Records counted.
   Records : Natural := 0;

   --  The Undo_Record_Attempted hook Count_Undo_Records installs.
   procedure Note_Record is
   begin
      Records := Records + 1;
   end Note_Record;

   procedure Count_Undo_Records (Count : Boolean) is
   begin
      Records := 0;
      Undo_Record_Attempted := (if Count then Note_Record'Access else null);
   end Count_Undo_Records;

   function Undo_Records return Natural is (Records);

end Files.Operations.Testing;
