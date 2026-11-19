with Files.History_Journal;
with Files.Model.History;
with Files.Operation_Jobs;
with Files.Undo_History;

package body Files.Operation_Commands is
   use type Files.Operation_Results.Operation_Status;
   use type Files.Types.Search_Scope;

   subtype Operation_Result is Files.Operation_Results.Operation_Result;

   --  Start Kind in a helper job unless Refusal refused it.
   function Start_Unless_Refused
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Kind     : Files.Operation_Jobs.Operation_Kind;
      Refusal  : Operation_Result)
      return Operation_Result is
     (if Refusal.Status /= Files.Operation_Results.Operation_Success
      then Refusal
      else Files.Operation_Jobs.Start (Model, Settings, Kind));

   --  What a command without refusal checks starts from.
   No_Refusal : constant Operation_Result := (Status => Files.Operation_Results.Operation_Success, others => <>);

   function Delete_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model) then
         declare
            Refusal : constant Operation_Result := Files.Operations.Trash_Refusal (Model);
         begin
            return Start_Unless_Refused (Model, Settings, Files.Operation_Jobs.Trash, Refusal);
         end;
      end if;
      return Files.Operations.Delete_Selected (Model, Settings);
   end Delete_Selected;

   function Delete_Selected_Permanently
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model) then
         return Start_Unless_Refused (Model, Settings, Files.Operation_Jobs.Delete_Permanently, No_Refusal);
      end if;
      return Files.Operations.Delete_Selected_Permanently (Model, Settings);
   end Delete_Selected_Permanently;

   function Restore_Selected_From_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model) then
         return Start_Unless_Refused (Model, Settings, Files.Operation_Jobs.Restore, No_Refusal);
      end if;
      return Files.Operations.Restore_Selected_From_Trash (Model, Settings);
   end Restore_Selected_From_Trash;

   function Empty_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model) then
         return Start_Unless_Refused (Model, Settings, Files.Operation_Jobs.Empty_Trash, No_Refusal);
      end if;
      return Files.Operations.Empty_Trash (Model, Settings);
   end Empty_Trash;

   function Duplicate_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model) then
         declare
            Refusal : constant Operation_Result :=
              Files.Operations.Creation_Refusal (Model, "error.duplicate.failed");
         begin
            return Start_Unless_Refused (Model, Settings, Files.Operation_Jobs.Duplicate, Refusal);
         end;
      end if;
      return Files.Operations.Duplicate_Selected (Model, Settings);
   end Duplicate_Selected;

   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Files.Operations.Archive_Format)
      return Operation_Result
   is
      use type Files.Operations.Archive_Format;
   begin
      if Files.Model.Background_Transfers (Model) then
         declare
            Refusal : constant Operation_Result :=
              Files.Operations.Creation_Refusal (Model, "error.compress.failed");
         begin
            return Start_Unless_Refused
              (Model, Settings,
               (if Format = Files.Operations.Zip_Archive then Files.Operation_Jobs.Compress_Zip
                else Files.Operation_Jobs.Compress_Seven_Zip),
               Refusal);
         end;
      end if;
      return Files.Operations.Compress_Selected (Model, Settings, Format);
   end Compress_Selected;

   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model) then
         declare
            Refusal : constant Operation_Result :=
              Files.Operations.Creation_Refusal (Model, "error.extract.failed");
         begin
            return Start_Unless_Refused (Model, Settings, Files.Operation_Jobs.Extract, Refusal);
         end;
      end if;
      return Files.Operations.Extract_Selected (Model, Settings);
   end Extract_Selected;

   function Run_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Scope    : Files.Types.Tree_Search_Scope)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model) then
         declare
            Refusal : constant Operation_Result := Files.Operations.Search_Refusal (Model);
         begin
            return Start_Unless_Refused
              (Model, Settings,
               (if Scope = Files.Types.Search_Contents then Files.Operation_Jobs.Search_Contents
                else Files.Operation_Jobs.Search_Names),
               Refusal);
         end;
      end if;
      return Files.Operations.Run_Search (Model, Settings, Scope);
   end Run_Search;

   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model)
        and then Files.History_Journal.Journals_Newest (Files.Model.History.State (Model), Files.Undo_History.Undo_Side)
      then
         return Start_Unless_Refused (Model, Settings, Files.Operation_Jobs.Undo, No_Refusal);
      end if;
      return Files.Operations.Undo_Last (Model, Settings);
   end Undo_Last;

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      if Files.Model.Background_Transfers (Model)
        and then Files.History_Journal.Journals_Newest (Files.Model.History.State (Model), Files.Undo_History.Redo_Side)
      then
         return Start_Unless_Refused (Model, Settings, Files.Operation_Jobs.Redo, No_Refusal);
      end if;
      return Files.Operations.Redo_Last (Model, Settings);
   end Redo_Last;

end Files.Operation_Commands;
