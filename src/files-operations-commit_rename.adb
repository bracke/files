separate (Files.Operations)
function Commit_Rename
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Targets     : constant Files.Model.Rename_Target_Vectors.Vector := Files.Model.Rename_Targets (Model);
   Current_Dir : constant String := Files.Model.Current_Path (Model);
   From_V      : Files.Types.String_Vectors.Vector;
   To_V        : Files.Types.String_Vectors.Vector;
   Identities  : Files.Types.String_Vectors.Vector;
   Success     : Natural := 0;
   Failure     : Natural := 0;
   Need_Reload : Boolean := False;
   First_Error_Key  : Unbounded_String := Null_Unbounded_String;
   First_Error_Path : Unbounded_String := Null_Unbounded_String;
   Focus_Name       : Unbounded_String := Null_Unbounded_String;
   --  Where the first entry left at neither name (Rename_Stranded_Key) is:
   --  told over any other error, as the user has to go and find it.
   Stranded_Path    : Unbounded_String := Null_Unbounded_String;

   --  The path the first error's message names: only a stranded entry's.
   function First_Error_Argument return String is
     (if To_String (First_Error_Key) = Files.File_System.Rename_Stranded_Key
      then To_String (First_Error_Path) else "");

   procedure Record_First_Error (Key : String; Path : String) is
   begin
      if First_Error_Key = Null_Unbounded_String then
         First_Error_Key := To_Unbounded_String (Key);
         First_Error_Path := To_Unbounded_String (Path);
      end if;
   end Record_First_Error;
begin
   if not Files.Model.Rename_Is_Active (Model) or else Targets.Is_Empty then
      return Disabled (Model, "error.rename.disabled");
   elsif Current_Dir = ""
     or else Files.Model.In_Recent_View (Model)
     or else Is_Trash_Directory (Current_Dir)
   then
      return Disabled (Model, "error.rename.disabled");
   end if;

   --  Capture old paths first (already done by Rename_Targets), then rename
   --  each item best-effort: successes are recorded for a single undo, and
   --  failures are collected without aborting the remaining renames.
   for Target of Targets loop
      declare
         Old_Full : constant String := To_String (Target.Old_Full_Path);
         Old_Name : constant String := To_String (Target.Old_Name);
         New_Name : constant String := To_String (Target.New_Name);
         --  A rename keeps each item in its own folder: a search or Recent
         --  lists items from other folders, and the listing a search left
         --  behind can outlive its flag until the reload lands.
         Parent   : constant String := Files.Fs_Primitives.Parent_Directory (Old_Full);
      begin
         --  An unchanged name stays as it is, whatever it holds; a new one
         --  is a name the user typed.
         if New_Name /= Old_Name and then not Files.File_System.Valid_Leaf_Name_At (New_Name, Parent) then
            Failure := Failure + 1;
            Record_First_Error ("error.name.invalid", Old_Full);
         elsif New_Name = Old_Name then
            if Exists_Safely (Old_Full) then
               Success := Success + 1;
               if Focus_Name = Null_Unbounded_String then
                  Focus_Name := Target.New_Name;
               end if;
            else
               Failure := Failure + 1;
               Need_Reload := True;
               Record_First_Error ("error.rename.source_missing", Old_Full);
            end if;
         else
            declare
               New_Path : constant String := Hostkit.Fs.Join (Parent, New_Name);
               Left_At  : Unbounded_String;
               Mutation : constant Files.File_System.Mutation_Result :=
                 Files.File_System.Rename_Item (Old_Full, New_Path, Left_At);
            begin
               if Mutation.Success then
                  Success := Success + 1;
                  Need_Reload := True;
                  From_V.Append (To_Unbounded_String (New_Path));
                  To_V.Append (Target.Old_Full_Path);
                  Identities.Append (To_Unbounded_String (Files.File_Identities.Token (New_Path)));
                  if Focus_Name = Null_Unbounded_String then
                     Focus_Name := Target.New_Name;
                  end if;
               else
                  Failure := Failure + 1;
                  if To_String (Mutation.Error_Key) = "error.rename.source_missing" then
                     Need_Reload := True;
                     Record_First_Error (To_String (Mutation.Error_Key), New_Path);
                  elsif To_String (Mutation.Error_Key) = Files.File_System.Rename_Stranded_Key then
                     --  The entry is at a name the listing does not show yet.
                     Need_Reload := True;
                     if Stranded_Path = Null_Unbounded_String then
                        Stranded_Path := Left_At;
                     end if;
                     Record_First_Error (To_String (Mutation.Error_Key), To_String (Left_At));
                  else
                     Record_First_Error (To_String (Mutation.Error_Key), New_Path);
                  end if;
               end if;
            end;
         end if;
      end;
   end loop;

   --  All renames failed. Keep the inline editors active (so the user can
   --  correct them) unless a vanished source forces a reload -- matching the
   --  single-item behavior exactly.
   if Success = 0 then
      if Stranded_Path /= Null_Unbounded_String then
         First_Error_Key := To_Unbounded_String (Files.File_System.Rename_Stranded_Key);
         First_Error_Path := Stranded_Path;
      end if;
      declare
         Failed_Status : constant Operation_Status :=
           (if To_String (First_Error_Key) = "error.name.invalid"
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
   end if;

   --  At least one rename succeeded; leave rename-edit mode even if the
   --  refresh fails, rather than stranding the model in it.
   Files.Model.Clear_Edit_State (Model);
   if not From_V.Is_Empty then
      Record_Undo
        (Model, Files.Model.Undo_Rename, From_V, To_V,
      Provenance => (Identities => Identities, others => <>));
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
           Hostkit.Fs.Join (Current_Dir, To_String (Focus_Name)));
   end if;

   Files.Model.Set_Error (Model, "");
   return
     Make_Result
       (Operation_Success,
        Path => Hostkit.Fs.Join (Current_Dir, To_String (Focus_Name)));
end Commit_Rename;
