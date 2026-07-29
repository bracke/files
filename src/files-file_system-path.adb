with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Files.UTF8;
with GNAT.OS_Lib;

separate (Files.File_System)
package body Path is
   use Ada.Strings.Unbounded;

   function Parent_Directory (Path : String) return String is
   begin
      if Path = "" then
         return "";
      end if;

      declare
         --  Containing_Directory resolves the parent cross-platform, trimming
         --  the final path component and handling trailing separators. It
         --  raises Use_Error at a filesystem root, where no parent exists.
         Parent : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Parent = "" or else Parent = Path then
            return "";
         end if;

         return Parent;
      end;
   exception
      when others =>
         return "";
   end Parent_Directory;

   function Normalize_Path
     (Path : String)
      return Path_Result
   is
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return
           (Status         => Path_Missing,
            Directory_Path => Null_Unbounded_String,
            Error_Key      => To_Unbounded_String ("error.path.missing"));
      end if;

      case Ada.Directories.Kind (Path) is
         when Ada.Directories.Directory =>
            return
              (Status         => Path_Valid,
               Directory_Path => To_Unbounded_String (Ada.Directories.Full_Name (Path)),
               Error_Key      => Null_Unbounded_String);
         when Ada.Directories.Ordinary_File =>
            return
              (Status         => Path_Valid,
               Directory_Path =>
                 To_Unbounded_String (Ada.Directories.Containing_Directory (Ada.Directories.Full_Name (Path))),
               Error_Key      => Null_Unbounded_String);
         when Ada.Directories.Special_File =>
            return
              (Status         => Path_Inaccessible,
               Directory_Path => Null_Unbounded_String,
               Error_Key      => To_Unbounded_String ("error.path.inaccessible"));
      end case;
   exception
      when others =>
         return
           (Status         => Path_Inaccessible,
            Directory_Path => Null_Unbounded_String,
            Error_Key      => To_Unbounded_String ("error.path.inaccessible"));
   end Normalize_Path;

   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String is
   begin
      if Parent_Path = "" then
         return Name;
      end if;

      return Ada.Directories.Compose
        (Containing_Directory => Parent_Path,
         Name                 => Name);

   exception
      when others =>
         --  Compose raises Name_Error for a name the host cannot represent --
         --  ':' and '\' are ordinary characters on POSIX but illegal on Windows.
         --  Joining is not the place to decide that: callers validate names
         --  themselves and report a rejection, and they need a path back in
         --  order to do it. Raising here turned "that name is not allowed" into
         --  a crash on Windows alone.
         declare
            Separator : constant Character := GNAT.OS_Lib.Directory_Separator;
         begin
            if Parent_Path (Parent_Path'Last) = Separator
              or else Parent_Path (Parent_Path'Last) = '/'
            then
               return Parent_Path & Name;
            end if;

            return Parent_Path & Separator & Name;
         end;
   end Join_Path;

   function Windows_Device_Basename (Name : String) return String is
      Result : Unbounded_String;
   begin
      for Character_Value of Name loop
         exit when Character_Value = '.';
         Append (Result, Ada.Characters.Handling.To_Upper (Character_Value));
      end loop;

      declare
         Text : constant String := To_String (Result);
         Last : Natural := Text'Last;
      begin
         while Last >= Text'First and then Text (Last) = ' ' loop
            Last := Last - 1;
         end loop;

         if Last < Text'First then
            return "";
         else
            return Text (Text'First .. Last);
         end if;
      end;
   end Windows_Device_Basename;

   function Is_Windows_Device_Name (Name : String) return Boolean is
      Base : constant String := Windows_Device_Basename (Name);
   begin
      return Base = "CON"
        or else Base = "PRN"
        or else Base = "AUX"
        or else Base = "NUL"
        or else Base = "CONIN$"
        or else Base = "CONOUT$"
        or else
          (Base'Length = 4
           and then (Base (Base'First .. Base'First + 2) = "COM"
                     or else Base (Base'First .. Base'First + 2) = "LPT")
           and then Base (Base'Last) in '1' .. '9');
   end Is_Windows_Device_Name;

   function Is_All_Whitespace (Name : String) return Boolean is
      Position : Natural := 0;
      Length   : Natural;
   begin
      if Name = "" then
         return True;
      end if;

      while Position < Name'Length loop
         Length := Files.UTF8.Whitespace_Separator_Length (Name, Position);
         if Length = 0 then
            return False;
         end if;

         Position := Position + Length;
      end loop;

      return True;
   end Is_All_Whitespace;

   function Ends_With_Whitespace (Name : String) return Boolean is
      Position : Natural := 0;
      Length   : Natural;
      Last     : Boolean := False;
   begin
      while Position < Name'Length loop
         Length := Files.UTF8.Whitespace_Separator_Length (Name, Position);
         Last := Length > 0 and then Position + Length = Name'Length;
         if Length = 0 then
            declare
               Next_Position : constant Natural := Files.UTF8.Next_Boundary (Name, Position);
            begin
               if Next_Position <= Position then
                  return False;
               end if;

               Position := Next_Position;
            end;
         else
            Position := Position + Length;
         end if;
      end loop;

      return Last;
   end Ends_With_Whitespace;

   function Valid_Leaf_Name (Name : String) return Boolean is
      Index     : Integer := Name'First;
      Codepoint : Natural := 0;
   begin
      if Name = ""
        or else Name = "."
        or else Name = ".."
        or else Name (Name'Last) = ' '
        or else Name (Name'Last) = '.'
        or else Is_Windows_Device_Name (Name)
        or else not Files.UTF8.Is_Valid (Name)
        or else Is_All_Whitespace (Name)
        or else Ends_With_Whitespace (Name)
      then
         return False;
      end if;

      while Index <= Name'Last loop
         Files.UTF8.Decode_Next_Codepoint (Name, Index, Codepoint);

         if Codepoint < 32
           or else Codepoint = 127
           or else Codepoint in 16#80# .. 16#9F#
         then
            return False;
         elsif Codepoint < 128 then
            declare
               Character_Value : constant Character := Character'Val (Codepoint);
            begin
               if Character_Value = '/'
                 or else Character_Value = '\'
                 or else Character_Value = '<'
                 or else Character_Value = '>'
                 or else Character_Value = ':'
                 or else Character_Value = Character'Val (34)
                 or else Character_Value = '|'
                 or else Character_Value = '?'
                 or else Character_Value = '*'
               then
                  return False;
               end if;
            end;
         end if;
      end loop;

      return True;
   end Valid_Leaf_Name;

   function Next_Untitled_Name
     (Directory_Path : String)
      return String
   is
      Candidate : Unbounded_String := To_Unbounded_String ("untitled.txt");
      Counter   : Positive := 2;

      function Counter_Text return String is
         Image : constant String := Positive'Image (Counter);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Counter_Text;
   begin
      while Ada.Directories.Exists (Join_Path (Directory_Path, To_String (Candidate))) loop
         Candidate := To_Unbounded_String ("untitled " & Counter_Text & ".txt");
         exit when Counter = Positive'Last;
         Counter := Counter + 1;
      end loop;

      return To_String (Candidate);
   exception
      when others =>
         return "untitled.txt";
   end Next_Untitled_Name;

end Path;
