with Files.File_System.Recovery_Registry;
with Files.File_System.Trash;
with Files.IO.Fs_Primitives;
with Files.Jobs.Context;
with Files.Diagnostics;
with Ada.Directories;
with Ada.Strings.Unbounded;

with Hostkit.Metadata;
with Files.File_System.Copying;
with Files.File_System.Recovery;
with Files.File_Identities;
with Files.IO.Errors;
with Files.Name_Parts;
with Files.Text_Case;

package body Files.File_System.Transfer is

   use Ada.Strings.Unbounded;

   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result is
   begin
      Files.IO.Errors.Reset;
      Copying.Copy_To_New_Path (Source_Path, Destination_Path, Batch => Batch);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return
           (Success   => False,
            Error_Key => Files.IO.Errors.Error_Key ("error.copy.failed"));
   end Copy_Tree;

   function Copy_Tree
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result is separate;

   function Publish_Staged
     (Staged   : String;
      Target   : String;
      Identity : out UString;
      Revision : out UString)
      return Boolean
   is separate;

   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
   is separate;

   function Execute_Drop_Import
     (Plans   : Drop_Import_Plan_Vectors.Vector;
      Created : out Created_Entry_Vectors.Vector;
      Cancel  : Cancellation_Check := Job_Cancelled;
      Batch   : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result
   is separate;

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
   is separate;

   procedure Put_Back_Replaced
     (Replaced, Replaced_Identity : in out Files.Types.UString;
      Destination                 : String;
      Result                      : in out Mutation_Result)
   is separate;

end Files.File_System.Transfer;
