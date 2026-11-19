separate (Files.Operations)
function Commit_Rename
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Targets     : constant Files.Model.Rename.Target_Vectors.Vector := Files.Model.Rename.Targets (Model);
   Current_Dir : constant String := Files.Model.Current_Path (Model);
   --  Each rename done: the new path, the old one, and the identity there.
   Renamed     : Files.Undo_History.Undo_Item_Vectors.Vector;
   Success     : Natural := 0;
   Failure     : Natural := 0;
   Need_Reload : Boolean := False;
   First_Error_Key  : Unbounded_String := Null_Unbounded_String;
   First_Error_Path : Unbounded_String := Null_Unbounded_String;
   Focus_Name       : Unbounded_String := Null_Unbounded_String;
   --  The first renamed item's full path, in its own folder (a search lists
   --  items from other folders than the current one).
   Focus_Path       : Unbounded_String := Null_Unbounded_String;
   --  Where the first entry left at neither name (Rename_Stranded_Key) is:
   --  told over any other error, as the user has to go and find it.
   Stranded_Path    : Unbounded_String := Null_Unbounded_String;

   --  What the first error was, where the outcome depends on it.
   type Error_Reason is
     (Invalid_Name,   --  A name the folder cannot hold: Operation_Invalid_Name.
      Stranded,       --  An entry left at neither name: its message names it.
      Other_Error);
   First_Error_Reason : Error_Reason := Other_Error;

   --  The path the first error's message names: only a stranded entry's.
   function First_Error_Argument return String is
     (if First_Error_Reason = Stranded then To_String (First_Error_Path) else "");

   procedure Record_First_Error (Key : String; Path : String; Reason : Error_Reason := Other_Error) is
   begin
      if First_Error_Key = Null_Unbounded_String then
         First_Error_Key := To_Unbounded_String (Key);
         First_Error_Path := To_Unbounded_String (Path);
         First_Error_Reason := Reason;
      end if;
   end Record_First_Error;

   --  How renaming one target ended.
   type Target_Outcome is record
      --  It is at its new name (or kept an unchanged one that still exists).
      Succeeded  : Boolean := False;
      --  The listing no longer shows it as it is: it moved, vanished or
      --  was stranded.
      Reload     : Boolean := False;
      --  Succeeded: its full path now, in its own folder.
      Focus_Path : Unbounded_String;
      --  Succeeded by an actual rename: the Undo item that reverses it.
      Has_Undo   : Boolean := False;
      Undo       : Files.Undo_History.Undo_Item;
      --  Failed: the message key, the path it names and why; a stranded
      --  entry's path is where it was left.
      Error_Key  : Unbounded_String;
      Error_Path : Unbounded_String;
      Reason     : Error_Reason := Other_Error;
   end record;

   --  Rename one target within its own folder. An unchanged name stays as it
   --  is, whatever it holds, and succeeds while the entry exists; a new one
   --  is a name the user typed, refused when the folder cannot hold it.
   function Rename_Target (Target : Files.Model.Rename.Rename_Target) return Target_Outcome is
      Old_Full : constant String := To_String (Target.Old_Full_Path);
      Old_Name : constant String := To_String (Target.Old_Name);
      New_Name : constant String := To_String (Target.New_Name);
      --  A rename keeps each item in its own folder: a search or Recent
      --  lists items from other folders, and the listing a search left
      --  behind can outlive its flag until the reload lands.
      Parent   : constant String := Files.Fs_Primitives.Parent_Directory (Old_Full);
      Outcome  : Target_Outcome;

      procedure Fail (Key : String; Path : String; Reason : Error_Reason := Other_Error) is
      begin
         Outcome.Error_Key := To_Unbounded_String (Key);
         Outcome.Error_Path := To_Unbounded_String (Path);
         Outcome.Reason := Reason;
      end Fail;
   begin
      if New_Name /= Old_Name and then not Files.File_System.Valid_Leaf_Name_At (New_Name, Parent) then
         Fail ("error.name.invalid", Old_Full, Invalid_Name);
      elsif New_Name = Old_Name then
         --  refusal-safe: a refused lookup counts the unchanged name as a failure
         if Files.Fs_Primitives.Entry_Exists (Old_Full) then
            Outcome.Succeeded := True;
            Outcome.Focus_Path := To_Unbounded_String (Hostkit.Fs.Join (Parent, New_Name));
         else
            Outcome.Reload := True;
            Fail ("error.rename.source_missing", Old_Full);
         end if;
      else
         declare
            New_Path : constant String := Hostkit.Fs.Join (Parent, New_Name);
            Left_At  : Unbounded_String;
            Why      : Files.File_System.Rename_Failure;
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Rename_Item (Old_Full, New_Path, Left_At, Why);
         begin
            if Mutation.Success then
               Outcome.Succeeded := True;
               Outcome.Reload := True;
               Outcome.Focus_Path := To_Unbounded_String (New_Path);
               Outcome.Has_Undo := True;
               Outcome.Undo :=
                 (From     => To_Unbounded_String (New_Path),
                  To       => Target.Old_Full_Path,
                  Identity => To_Unbounded_String (Files.File_Identities.Token (New_Path)),
                  others   => <>);
            else
               case Why is
                  when Files.File_System.Rename_Source_Missing =>
                     --  What is missing is the entry renamed, by its old name.
                     Outcome.Reload := True;
                     Fail (To_String (Mutation.Error_Key), Old_Full);
                  when Files.File_System.Rename_Stranded =>
                     --  The entry is at a name the listing does not show yet.
                     Outcome.Reload := True;
                     Fail (To_String (Mutation.Error_Key), To_String (Left_At), Stranded);
                  when Files.File_System.Rename_Name_Invalid =>
                     Fail (To_String (Mutation.Error_Key), New_Path, Invalid_Name);
                  when Files.File_System.Rename_Refused =>
                     Fail (To_String (Mutation.Error_Key), New_Path);
               end case;
            end if;
         end;
      end if;
      return Outcome;
   end Rename_Target;

   --  Every rename failed. Keep the inline editors active (so the user can
   --  correct them) unless a vanished or stranded entry forces a reload; a
   --  stranded entry is told over any other error, as the user has to go and
   --  find it.
   function All_Failed return Operation_Result is
   begin
      if Stranded_Path /= Null_Unbounded_String then
         First_Error_Key := To_Unbounded_String (Files.File_System.Rename_Stranded_Key);
         First_Error_Path := Stranded_Path;
         First_Error_Reason := Stranded;
      end if;
      declare
         Failed_Status : constant Operation_Status :=
           (if First_Error_Reason = Invalid_Name
            then Operation_Invalid_Name
            else Operation_Failed);
      begin
         Files.Model.Set_Error (Model, To_String (First_Error_Key), First_Error_Argument);
         if Need_Reload then
            Reload_With_Error (Model, Settings, To_String (First_Error_Key), First_Error_Argument);
         end if;
         return
           Make_Result
             (Failed_Status,
              To_String (First_Error_Key),
              To_String (First_Error_Path));
      end;
   end All_Failed;
begin
   if not Files.Model.Rename.Is_Active (Model) or else Targets.Is_Empty then
      return Disabled (Model, "error.rename.disabled");
   elsif Current_Dir = ""
     or else Files.Model.In_Recent_View (Model)
     or else Is_Trash_Directory (Current_Dir)
   then
      return Disabled (Model, "error.rename.disabled");
   end if;

   --  Capture old paths first (already done by Rename.Targets), then rename
   --  each item best-effort: successes are recorded for a single undo, and
   --  failures are collected without aborting the remaining renames.
   for Target of Targets loop
      declare
         Outcome : constant Target_Outcome := Rename_Target (Target);
      begin
         Need_Reload := Need_Reload or else Outcome.Reload;
         if Outcome.Succeeded then
            Success := Success + 1;
            if Outcome.Has_Undo then
               Renamed.Append (Outcome.Undo);
            end if;
            if Focus_Name = Null_Unbounded_String then
               Focus_Name := Target.New_Name;
               Focus_Path := Outcome.Focus_Path;
            end if;
         else
            Failure := Failure + 1;
            if Outcome.Reason = Stranded and then Stranded_Path = Null_Unbounded_String then
               Stranded_Path := Outcome.Error_Path;
            end if;
            Record_First_Error (To_String (Outcome.Error_Key), To_String (Outcome.Error_Path), Outcome.Reason);
         end if;
      end;
   end loop;

   if Success = 0 then
      return All_Failed;
   end if;

   --  At least one rename succeeded; leave rename-edit mode even if the
   --  refresh fails, rather than stranding the model in it.
   Files.Model.Clear_Edit_State (Model);
   if not Renamed.Is_Empty then
      Record_Undo (Model, Files.Undo_History.Undo_Rename, Published (Renamed));
   end if;

   if Need_Reload then
      declare
         Reload : constant Operation_Result :=
           Reload_Current_Directory (Model, Settings, To_String (Focus_Name));
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;
   end if;

   if Stranded_Path /= Null_Unbounded_String then
      --  Some items renamed, but one was left at neither name: say where.
      Files.Model.Set_Error (Model, Files.File_System.Rename_Stranded_Key, To_String (Stranded_Path));
      return
        Make_Result
          (Operation_Success,
           Files.File_System.Rename_Stranded_Key,
           To_String (Stranded_Path));
   elsif Failure > 0 then
      --  Some items renamed, some failed: report partial success so the
      --  user learns not every rename landed.
      Files.Model.Set_Error (Model, "error.rename.partial");
      return
        Make_Result
          (Operation_Success,
           "error.rename.partial",
           To_String (Focus_Path));
   end if;

   Files.Model.Set_Error (Model, "");
   return
     Make_Result
       (Operation_Success,
        Path => To_String (Focus_Path));
end Commit_Rename;
