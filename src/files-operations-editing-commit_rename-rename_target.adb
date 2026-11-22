separate (Files.Operations.Editing.Commit_Rename)
function Rename_Target (Target : Files.Model.Rename.Rename_Target) return Target_Outcome is
   Old_Full : constant String := To_String (Target.Old_Full_Path);
   Old_Name : constant String := To_String (Target.Old_Name);
   New_Name : constant String := To_String (Target.New_Name);
   --  A rename keeps each item in its own folder: a search or Recent
   --  lists items from other folders, and the listing a search left
   --  behind can outlive its flag until the reload lands.
   Parent   : constant String := Files.IO.Fs_Primitives.Parent_Directory (Old_Full);
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
      if Files.IO.Fs_Primitives.Entry_Exists (Old_Full) then
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
