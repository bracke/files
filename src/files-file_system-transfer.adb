package body Files.File_System.Transfer is

   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result
     renames Files.File_System.Copy_Tree;

   function Copy_Tree
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result
     renames Files.File_System.Copy_Tree;

   function Publish_Staged
     (Staged   : String;
      Target   : String;
      Identity : out UString;
      Revision : out UString)
      return Boolean
     renames Files.File_System.Publish_Staged;

   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
     renames Files.File_System.Plan_Drop_Import;

   function Says_Only_Stopped (Error_Key : String; Reading : Failure_Reading) return Boolean
     renames Files.File_System.Says_Only_Stopped;

   function Job_Cancelled return Cancellation_Check
     renames Files.File_System.Job_Cancelled;

   function Import_Replacing
     (Source, Destination   : String;
      Mode                  : Drop_Import_Mode;
      Replace               : Boolean;
      Replaced              : out Files.Types.UString;
      Replaced_Identity     : out Files.Types.UString;
      Created_Identity      : out Files.Types.UString;
      Created_Tree_Revision : out Files.Types.UString;
      Preserved             : access procedure (Backup, Backup_Identity : String) := null;
      Cancel                : Cancellation_Check := Job_Cancelled;
      Batch                 : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result
     renames Files.File_System.Import_Replacing;

   procedure Put_Back_Replaced
     (Replaced, Replaced_Identity : in out Files.Types.UString;
      Destination                 : String;
      Result                      : in out Mutation_Result)
     renames Files.File_System.Put_Back_Replaced;

end Files.File_System.Transfer;
