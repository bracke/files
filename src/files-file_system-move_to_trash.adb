with Files.Durable_Writes;
with Files.Durability;
with Hostkit.Durability;
separate (Files.File_System)
function Move_To_Trash
  (Path          : String;
   Trashed_Path  : out Files.Types.UString;
   Recorded_Path : String := "")
   return Mutation_Result
is
   function Unique_Trash_Name
     (Files_Directory : String;
      Info_Directory  : String;
      Name            : String)
      return String
   is
      --  A leaf holds at most 255 bytes. The freedesktop info file adds
      --  ".trashinfo" to the name, and a clash adds a counter (".2" up to
      --  ".2147483647"). A name with no room for what is added is cut down to
      --  fit -- keeping its extension, never inside a UTF-8 sequence -- or the
      --  item could never be trashed. The info file's Path= keeps the
      --  original, which restore uses. The macOS home trash has no info file,
      --  so there a name is cut only when a counter must be added.
      Info_Suffix     : constant String := ".trashinfo";
      Longest_Counter : constant String := ".2147483647";
      Info_Room       : constant Natural := (if Info_Directory = "" then 0 else Info_Suffix'Length);

      function Fit (Room : Natural) return String is (Files.Leaf_Names.Fit (Name, Room));

      --  Room for the info file's suffix and the longest counter.
      Base      : constant String :=
        (if Info_Directory = ""
         then Name
         else Fit (Files.Leaf_Names.Max_Length - Info_Room - Longest_Counter'Length));
      Counter   : Positive := 2;
      Candidate : Unbounded_String := To_Unbounded_String (Base);
   begin
      --  A name that cannot be looked at raises: the trash is refused,
      --  not handed a name that may be in use.
      while Files.Fs_Primitives.Is_Taken (Hostkit.Fs.Join (Files_Directory, To_String (Candidate)))
        or else (Info_Directory /= ""
                 and then
                   Files.Fs_Primitives.Is_Taken
                     (Hostkit.Fs.Join (Info_Directory, To_String (Candidate) & Info_Suffix)))
      loop
         declare
            Suffix : constant String := "." & Natural_Text (Counter);
         begin
            Candidate := To_Unbounded_String
              ((if Info_Directory = "" then Fit (Files.Leaf_Names.Max_Length - Suffix'Length) else Base) & Suffix);
         end;
         exit when Counter = Positive'Last;
         Counter := Counter + 1;
      end loop;

      return To_String (Candidate);
   end Unique_Trash_Name;

   function Trash_Info_Path_Value (Path_Value : String) return String is
      Hex    : constant String := "0123456789ABCDEF";
      Result : Unbounded_String;

      function Is_Unreserved (Value : Character) return Boolean is
      begin
         return (Value >= 'A' and then Value <= 'Z')
           or else (Value >= 'a' and then Value <= 'z')
           or else (Value >= '0' and then Value <= '9')
           or else Value = '-'
           or else Value = '.'
           or else Value = '_'
           or else Value = '~'
           or else Value = '/';
      end Is_Unreserved;
   begin
      for Value of Path_Value loop
         if Is_Unreserved (Value) then
            Append (Result, Value);
         else
            declare
               Code : constant Natural := Character'Pos (Value);
            begin
               Append (Result, '%');
               Append (Result, Hex (Code / 16 + 1));
               Append (Result, Hex (Code mod 16 + 1));
            end;
         end if;
      end loop;

      return To_String (Result);
   end Trash_Info_Path_Value;

   Backend    : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   Macos_Home : constant Boolean := Backend = Trash_Macos_Home;
   --  Move_To_Trash_Preflight, with a failure inside it a refusal as one
   --  in the body would be. It runs during elaboration, before the body's
   --  own Reset, so it clears the I/O error first: the key its handler
   --  reads is then this preflight's, not an earlier operation's.
   function Checked_Preflight return Mutation_Result is
   begin
      Files.Io_Errors.Reset;
      return Move_To_Trash_Preflight (Path);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.trash.failed"));
   end Checked_Preflight;

   --  Whether the request may go ahead at all, checked once: the body
   --  returns this refusal before anything is moved.
   Preflight  : constant Mutation_Result := Checked_Preflight;
   --  An item on another volume goes to that volume's own trash: a rename,
   --  not a copy of everything into home.
   Volume     : constant String :=
     --  Only for an item the preflight accepts: choosing a volume's trash
     --  makes it there, which a refused request must not do.
     (if Backend in Trash_Xdg_Data_Home | Trash_Home_Data and then Preflight.Success
      then Volume_Trash_For (Path)
      else "");
   Base       : constant String := (if Volume /= "" then Volume else Trash_Base_Path);
   --  macOS ~/.Trash stores items at the top level, without the freedesktop
   --  files/info split or .trashinfo sidecars, so Finder recognizes them.
   Files_Dir  : constant String :=
     (if Base = "" then ""
      elsif Macos_Home then Base
      else Hostkit.Fs.Join (Base, "files"));
   Info_Dir   : constant String :=
     (if Base = "" or else Macos_Home then "" else Hostkit.Fs.Join (Base, "info"));
   Name      : Unbounded_String;
   Target    : Unbounded_String;
   Info_Path : Unbounded_String;
   --  The info file this call wrote, once it has: only that one is removed.
   Info_Identity : Unbounded_String;

   --  Where the item came from, as its info file says it: absolute for the
   --  home trash, relative to the volume's top for a volume trash.
   function Info_Path_Text return String is
      --  The path as given, made absolute: the item moved is the link, not
      --  what it points at.
      Original : constant String :=
        Files.Fs_Primitives.Absolute_Name (if Recorded_Path = "" then Path else Recorded_Path);
   begin
      if Volume /= "" then
         declare
            Relative : constant String := Relative_To_Top (Original, Volume_Trash_Top (Volume));
         begin
            if Relative /= "" then
               return Relative;
            end if;
         end;
      end if;
      return Original;
   end Info_Path_Text;

   procedure Delete_Info_File_If_Present is
   begin
      Files.Durable_Writes.Remove_Owned (To_String (Info_Path), To_String (Info_Identity));
   end Delete_Info_File_If_Present;

   function Send_To_Recycle_Bin return Mutation_Result is separate;
   function Send_To_Finder_Trash return Mutation_Result is separate;
   procedure Prepare_Directories is separate;
   procedure Write_Info_File is separate;
   function Move_Item return Mutation_Result is separate;
begin
   Files.Io_Errors.Reset;
   Trashed_Path := Null_Unbounded_String;
   if not Preflight.Success then
      return Preflight;
   end if;

   if Backend = Trash_Windows_Recycle_Bin then
      return Send_To_Recycle_Bin;
   end if;

   if Backend = Trash_Macos_Native then
      return Send_To_Finder_Trash;
   end if;

   Prepare_Directories;

   Name := To_Unbounded_String
     (Unique_Trash_Name (Files_Dir, Info_Dir, Files.Fs_Primitives.Leaf_Text (Path)));
   Target := To_Unbounded_String (Hostkit.Fs.Join (Files_Dir, To_String (Name)));

   if not Macos_Home then
      Info_Path := To_Unbounded_String (Hostkit.Fs.Join (Info_Dir, To_String (Name) & ".trashinfo"));
      Write_Info_File;
   end if;

   declare
      Moved : constant Mutation_Result := Move_Item;
   begin
      if not Moved.Success then
         return Moved;
      end if;
   end;

   Trashed_Path := Target;
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      declare
         Failed : constant Mutation_Result :=
           (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.trash.failed"));
      begin
         Delete_Info_File_If_Present;
         return Failed;
      end;
end Move_To_Trash;
