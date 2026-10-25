separate (Files.Operations)
function Empty_Trash
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Trash_Dir   : constant String :=
     (if Files.Model.Background_Transfers (Model) then "" else Files.File_System.Trash_Files_Directory);
   Load        : Files.File_System.Directory_Load_Result;
   Total       : Natural := 0;
   Failed      : Natural := 0;
   First_Error : Unbounded_String;
   Enumeration_Settings : Files.Settings.Settings_Model := Settings;
begin
   if Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Empty_Trash);
   end if;
   if Trash_Dir = "" then
      return Disabled (Model, "error.trash.unavailable");
   end if;

   --  Empty Trash purges every payload, regardless of display preferences.
   Enumeration_Settings.Show_Hidden_Files := True;
   Load := Files.File_System.Load_Directory (Trash_Dir, Enumeration_Settings);
   if not Load.Success then
      Files.Model.Set_Error (Model, To_String (Load.Error_Key));
      return Make_Result (Operation_Failed, To_String (Load.Error_Key), Trash_Dir);
   end if;

   for Item of Load.Items loop
      exit when Files.Job_Context.Cancelled;
      Total := Total + 1;
      declare
         --  Its labels went into the trash with it.
         Labeled  : constant String := To_String (Item.Full_Path);
         Mutation : constant Files.File_System.Mutation_Result :=
           Files.File_System.Delete_Trashed_Item (To_String (Item.Full_Path));
      begin
         if Mutation.Success then
            Files.Model.Note_Path_Removed (Model, Labeled);
         end if;
         if not Mutation.Success then
            Failed := Failed + 1;
            if Length (First_Error) = 0 then
               First_Error := Mutation.Error_Key;
            end if;
         end if;
      end;
   end loop;

   --  Reload the (now emptied) trash view regardless of per-item outcome.
   declare
      Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      pragma Unreferenced (Reload);
   begin
      null;
   end;

   --  Emptying the trash is terminal: no undo entry is recorded.
   if Total > 0 and then Failed = Total then
      declare
         Error_Key : constant String :=
           (if Length (First_Error) > 0 then To_String (First_Error) else "error.trash.empty_failed");
      begin
         Files.Model.Set_Error (Model, Error_Key);
         return Make_Result (Operation_Failed, Error_Key, Trash_Dir);
      end;
   elsif Failed > 0 then
      --  Mixed outcome: the survivors are reported as a non-fatal diagnostic.
      Files.Model.Set_Error (Model, "error.trash.empty_partial");
      return Make_Result (Operation_Success, Path => Trash_Dir);
   end if;

   Files.Model.Set_Error (Model, "");
   return Make_Result (Operation_Success, Path => Trash_Dir);
end Empty_Trash;
