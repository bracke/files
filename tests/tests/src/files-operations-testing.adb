with Ada.Real_Time;
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

   --  The fake throttle clock: an instant well inside the clock's range,
   --  how often it was read, and the reading that moves it a second on.
   Fake_Epoch       : constant Ada.Real_Time.Time :=
     Ada.Real_Time.Time_Of (1_000_000, Ada.Real_Time.Time_Span_Zero);
   Fake_Readings    : Natural := 0;
   Fake_Advance_At  : Natural := 0;

   --  The Checkpoint_Clock hook Fake_Checkpoint_Clock installs.
   function Fake_Now return Ada.Real_Time.Time is
      use type Ada.Real_Time.Time;
   begin
      Fake_Readings := Fake_Readings + 1;
      if Fake_Advance_At /= 0 and then Fake_Readings >= Fake_Advance_At then
         return Fake_Epoch + Ada.Real_Time.Seconds (1);
      end if;
      return Fake_Epoch;
   end Fake_Now;

   procedure Fake_Checkpoint_Clock (Fake : Boolean; Advance_At : Natural := 0) is
   begin
      Fake_Readings := 0;
      Fake_Advance_At := Advance_At;
      Checkpoint_Clock := (if Fake then Fake_Now'Access else null);
   end Fake_Checkpoint_Clock;

   function Checkpoint_Clock_Readings return Natural is (Fake_Readings);

   function Finalize_Paste_With_Kept_Copy
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String;
      Dest, Source, Identity, Tree_Revision : String)
      return Operation_Result is
   begin
      return Finalize_Paste_Execution
        (Model, Settings, Error_Key,
         (Dest_Path     => To_Unbounded_String (Dest),
          Source_Path   => To_Unbounded_String (Source),
          Identity      => To_Unbounded_String (Identity),
          Tree_Revision => To_Unbounded_String (Tree_Revision)));
   end Finalize_Paste_With_Kept_Copy;

end Files.Operations.Testing;
