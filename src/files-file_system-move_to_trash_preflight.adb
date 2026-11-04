separate (Files.File_System)
function Move_To_Trash_Preflight
  (Path : String)
   return Mutation_Result
is
   Base : constant String := Trash_Base_Path;

   Uses_Native_Trash : constant Boolean :=
     Trash_Backend_Of_Current_Environment in Trash_Windows_Recycle_Bin | Trash_Macos_Native;

   --  A filesystem root ("/", "C:\"): its containing directory is itself,
   --  or does not exist at all.
   function Is_Filesystem_Root return Boolean is
   begin
      if Hostkit.Fs.Is_Link (Path) then
         return False;
      end if;
      declare
         Full : constant String := Ada.Directories.Full_Name (Path);
      begin
         return Full = "" or else Ada.Directories.Containing_Directory (Full) = Full;
      end;
   exception
      when Ada.Directories.Use_Error => return True;
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Is_Filesystem_Root;

   function Source_Exists return Boolean is
   begin
      return Path /= "" and then Files.Fs_Primitives.Entry_Exists (Path);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Source_Exists;

   function Normalized_Text (Value : String) return String is
   begin
      if Value = "" then
         return "";
      elsif Hostkit.Fs.Is_Link (Value) then
         --  Resolve the parent to find the link's location, never its target.
         return Join_Path
           (Ada.Directories.Full_Name (Ada.Directories.Containing_Directory (Value)),
            Ada.Directories.Simple_Name (Value));
      elsif Ada.Directories.Exists (Value) then
         return Ada.Directories.Full_Name (Value);
      else
         return Value;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return Value;
   end Normalized_Text;

   function Is_Same_Or_Inside
     (Child  : String;
      Parent : String)
      return Boolean is
     (Hostkit.Fs.Is_Same_Or_Inside (Normalized_Text (Child), Normalized_Text (Parent)));

   --  A volume's trash (.Trash-$uid, .Trash/$uid), or anything in it: its
   --  files/ and info/ would go into themselves.
   function Inside_Volume_Trash return Boolean is
      Current : Unbounded_String := To_Unbounded_String (Normalized_Text (Path));
   begin
      loop
         declare
            Text   : constant String := To_String (Current);
            Parent : constant String :=
              (if Text = "" then "" else Ada.Directories.Containing_Directory (Text));
            Name   : constant String := (if Text = "" then "" else Ada.Directories.Simple_Name (Text));
            Upper  : constant String :=
              (if Parent = "" then "" else Ada.Directories.Simple_Name (Parent));
         begin
            exit when Text = "" or else Parent = Text;
            if ((Name'Length >= 6 and then Name (Name'First .. Name'First + 5) = ".Trash")
                or else Upper = ".Trash")
              and then Valid_Volume_Trash_Base (Text)
            then
               return True;
            end if;
            Current := To_Unbounded_String (Parent);
         end;
      end loop;
      return False;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Inside_Volume_Trash;
begin
   --  The native backends used to be refused here, because nothing called
   --  them: a desktop trash we could not reach was the same as no trash. They
   --  are wired up now, so refusing the platform's own trash before even
   --  looking at the path meant deleting on Windows always failed with
   --  "native unavailable" while the Recycle Bin sat there unused.
   --
   --  A native backend gets the same checks as any other: it still may not
   --  swallow a path that does not exist, or the filesystem root.
   if not Source_Exists or else Is_Filesystem_Root then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.failed"));
   end if;

   --  Everything below is about OUR trash directory: that it exists, that we
   --  are not trying to throw it into itself. A native backend has no such
   --  directory -- the Recycle Bin is the shell's, not ours -- so those checks
   --  do not apply to it, and applying them anyway reported "no trash" on the
   --  one platform whose trash is always there.
   --  But the Recycle Bin is not everywhere: asked to recycle from a network
   --  share or a USB stick, the shell deletes the item for good, silently.
   --  Refuse there, before anything is touched, so the user can choose a
   --  permanent delete knowingly.
   if Uses_Native_Trash then
      if Hostkit.Trash.Current.Uses_Recycle_Bin and then not Hostkit.Trash.Can_Hold (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.volume_unavailable"));
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   end if;

   if Base = "" then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.unavailable"));
   elsif not Path_Can_Be_Directory (Base) then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.unavailable"));
   elsif Is_Same_Or_Inside (Base, Path)
     or else Is_Same_Or_Inside (Path, Base)
     or else Inside_Volume_Trash
   then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.failed"));
   end if;

   return (Success => True, Error_Key => Null_Unbounded_String);
end Move_To_Trash_Preflight;
