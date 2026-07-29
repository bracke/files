separate (Files.File_System)
   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
   is
      Base : constant String := Trash_Base_Path;

      Uses_Native_Trash : constant Boolean :=
        Trash_Backend_For_Base in Trash_Windows_Recycle_Bin | Trash_Macos_Native;

      function Source_Exists return Boolean is
      begin
         return Path /= "" and then Ada.Directories.Exists (Path);
      exception
         when others =>
            return False;
      end Source_Exists;

      function Normalized_Text (Value : String) return String is
      begin
         if Value = "" then
            return "";
         elsif Ada.Directories.Exists (Value) then
            return Ada.Directories.Full_Name (Value);
         else
            return Value;
         end if;
      exception
         when others =>
            return Value;
      end Normalized_Text;

      function Is_Same_Or_Inside
        (Child  : String;
         Parent : String)
         return Boolean
      is
         Clean_Child  : constant String := Normalized_Text (Child);
         Clean_Parent : constant String := Normalized_Text (Parent);
         Next         : Natural;
      begin
         if Clean_Child = "" or else Clean_Parent = "" then
            return False;
         elsif Clean_Child = Clean_Parent then
            return True;
         elsif Clean_Child'Length <= Clean_Parent'Length then
            return False;
         elsif Clean_Child (Clean_Child'First .. Clean_Child'First + Clean_Parent'Length - 1) /= Clean_Parent then
            return False;
         end if;

         if Clean_Parent (Clean_Parent'Last) = '/'
           or else Clean_Parent (Clean_Parent'Last) = '\'
         then
            return True;
         end if;

         Next := Clean_Child'First + Clean_Parent'Length;
         return Clean_Child (Next) = '/' or else Clean_Child (Next) = '\';
      exception
         when others =>
            return False;
      end Is_Same_Or_Inside;
   begin
      --  The native backends used to be refused here, because nothing called
      --  them: a desktop trash we could not reach was the same as no trash. They
      --  are wired up now, so refusing the platform's own trash before even
      --  looking at the path meant deleting on Windows always failed with
      --  "native unavailable" while the Recycle Bin sat there unused.
      --
      --  A native backend gets the same checks as any other: it still may not
      --  swallow a path that does not exist, or the filesystem root.
      if not Source_Exists then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;

      --  Everything below is about OUR trash directory: that it exists, that we
      --  are not trying to throw it into itself. A native backend has no such
      --  directory -- the Recycle Bin is the shell's, not ours -- so those checks
      --  do not apply to it, and applying them anyway reported "no trash" on the
      --  one platform whose trash is always there.
      if Uses_Native_Trash then
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
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end Move_To_Trash_Preflight;
