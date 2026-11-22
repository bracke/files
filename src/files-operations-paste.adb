with Files.File_System;
with Files.Model.Recent;
with Files.File_System.Trash;
with Ada.Strings.Unbounded;
with Files.IO.Fs_Primitives;
with Files.Transfer_Jobs;
with Files.Operations.Support;
with Files.Diagnostics;
with Files.Jobs.Copy_Context;
with Files.Operations.Undo_Recording;
with Files.Model.Pasting;
with Files.Undo.History;

package body Files.Operations.Paste is

   use Ada.Strings.Unbounded;
   use type Files.File_System_Types.Drop_Import_Mode;
   use type Files.Undo.History.Undo_Action_Kind;
   use Files.Operations.Support;

   --  The undo history is recorded by Files.Operations.Undo_Recording; these name it
   --  here for the bodies that record.
   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Undo.History.Undo_Action_Kind;
      Items       : Files.Undo.History.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Undo.History.Recorded_Original_Vectors.Vector :=
        Files.Undo.History.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Undo.History.Kept_Copy_Vectors.Vector := Files.Undo.History.Kept_Copy_Vectors.Empty_Vector)
     renames Files.Operations.Undo_Recording.Record_Undo;

   function Existing_Destination_Paths
     (Directory : String;
      Listed    : out Boolean)
      return Files.Types.String_Vectors.Vector
   is separate;

   function Paste_Work_List
     (Plans     : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Directory : String)
      return Files.Paste.Work_Item_Vectors.Vector
   is separate;

   Paste_Execution_First_Batch : constant := 32;

   --  Resolve a preserved original's destination and check its live entry,
   --  then record it in the model's paste execution.
   procedure Record_Paste_Replaced_Trash
     (Model         : in out Files.Model.Window_Model;
      Trash_Path    : Files.Types.UString;
      Identity      : String;
      Original_Path : String);

   procedure Record_Paste_Replaced_Trash
     (Model         : in out Files.Model.Window_Model;
      Trash_Path    : Files.Types.UString;
      Identity      : String;
      Original_Path : String) is separate;

   --  Check a published destination against its creation snapshot, then
   --  record the write in the model's paste execution.
   procedure Record_Paste_Write
     (Model         : in out Files.Model.Window_Model;
      Dest_Path     : Files.Types.UString;
      Source_Path   : Files.Types.UString;
      Name          : String;
      Identity      : String;
      Tree_Revision : String;
      Retain_Verified_Snapshot : Boolean := False);

   procedure Record_Paste_Write
     (Model         : in out Files.Model.Window_Model;
      Dest_Path     : Files.Types.UString;
      Source_Path   : Files.Types.UString;
      Name          : String;
      Identity      : String;
      Tree_Revision : String;
      Retain_Verified_Snapshot : Boolean := False) is separate;

   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result is separate;

   function Begin_Paste_To
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Destination    : String;
      Mode           : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result
   is separate;

   function Resolve_Paste_Conflict
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Choice    : Conflict_Choice;
      Apply_All : Boolean)
      return Operation_Result
   is separate;

   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result
   is separate;

   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model) is separate;

   procedure Begin_Paste_Execution
     (Model           : in out Files.Model.Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System_Types.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
   is
      Writes : Natural := 0;
   begin
      for Action of Actions loop
         if not Action.Skip then
            Writes := Writes + 1;
         end if;
      end loop;
      Files.Model.Pasting.Begin_Execution
        (Model, Actions, Mode, Clear_Clipboard,
         Batch => (if Writes > 1 then Files.Jobs.Copy_Context.Create else Files.Jobs.Copy_Context.Empty_Session));
   end Begin_Paste_Execution;

   procedure Record_Paste_So_Far (Model : in out Files.Model.Window_Model) is
   begin
      if Files.Model.Pasting.Execution_Is_Active (Model) then
         Record_Paste_Execution (Model);
      end if;
   end Record_Paste_So_Far;

   procedure Record_Paste_Execution
     (Model : in out Files.Model.Window_Model;
      Kept  : Kept_Copy := No_Kept_Copy)
   is separate;

   function Finalize_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String;
      Kept      : Kept_Copy := No_Kept_Copy)
      return Operation_Result
   is separate;

end Files.Operations.Paste;
