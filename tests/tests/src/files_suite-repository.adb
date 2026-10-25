with Ada.Directories;
with Ada.Strings.Fixed;

with Project_Tools.Files;

package body Files_Suite.Repository is

   use type Ada.Directories.File_Kind;

   function Root return String is
      Found : constant String :=
        Project_Tools.Files.Find_Root_Upward (Ada.Directories.Current_Directory, "files.gpr");
   begin
      if Found = "" then
         raise Program_Error with
           "no files.gpr in " & Ada.Directories.Current_Directory
           & " or any directory above it: run the suite from inside the repository";
      end if;
      return Found;
   end Root;

   function Path (Relative : String) return String is
   begin
      return Root & "/" & Relative;
   end Path;

   function File_Exists (Relative : String) return Boolean is
   begin
      return Project_Tools.Files.File_Exists (Path (Relative));
   end File_Exists;

   function Has_Suffix (Text : String; Suffix : String) return Boolean is
     (Text'Length >= Suffix'Length
      and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix);

   function Is_Ada_Text (Name : String) return Boolean is
     (Has_Suffix (Name, ".ads") or else Has_Suffix (Name, ".adb") or else Has_Suffix (Name, ".gpr"));

   function Without_Comments (Text : String) return String is
      Result    : String (1 .. Text'Length);
      Last      : Natural := 0;
      In_String : Boolean := False;
      I         : Natural := Text'First;

      procedure Keep (Item : Character) is
      begin
         Last := Last + 1;
         Result (Last) := Item;
      end Keep;

      --  A tick right after a name or a closing parenthesis is an attribute
      --  or qualification, not the start of a character literal.
      function Opens_Character_Literal (At_Tick : Positive) return Boolean is
        (At_Tick + 2 <= Text'Last
         and then Text (At_Tick + 2) = '''
         and then (At_Tick = Text'First
                   or else Text (At_Tick - 1) not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | ')'));
   begin
      while I <= Text'Last loop
         if Text (I) = ASCII.LF then
            In_String := False;
            Keep (Text (I));
            I := I + 1;
         elsif In_String then
            --  A doubled quote closes and at once reopens the literal.
            In_String := Text (I) /= '"';
            Keep (Text (I));
            I := I + 1;
         elsif Text (I) = '"' then
            In_String := True;
            Keep (Text (I));
            I := I + 1;
         elsif Text (I) = ''' and then Opens_Character_Literal (I) then
            for Offset in 0 .. 2 loop
               Keep (Text (I + Offset));
            end loop;
            I := I + 3;
         elsif Text (I) = '-' and then I < Text'Last and then Text (I + 1) = '-' then
            while I <= Text'Last and then Text (I) /= ASCII.LF loop
               I := I + 1;
            end loop;
         else
            Keep (Text (I));
            I := I + 1;
         end if;
      end loop;
      return Result (1 .. Last);
   end Without_Comments;

   --  Whether the file at Full_Path contains Pattern, ignoring comments in Ada.
   function Text_Contains (Full_Path : String; Pattern : String) return Boolean is
      Raw : constant String := Project_Tools.Files.Read_Raw_File (Full_Path);
   begin
      if Is_Ada_Text (Full_Path) then
         return Ada.Strings.Fixed.Index (Without_Comments (Raw), Pattern) > 0;
      end if;
      return Ada.Strings.Fixed.Index (Raw, Pattern) > 0;
   end Text_Contains;

   function File_Contains (Relative : String; Pattern : String) return Boolean is
      Full : constant String := Path (Relative);
   begin
      if not Project_Tools.Files.File_Exists (Full) then
         raise Program_Error with "the repository has no " & Relative & " to inspect (looked for " & Full & ")";
      end if;
      return Text_Contains (Full, Pattern);
   end File_Contains;

   function Tree_Contains (Directory : String; Pattern : String) return Boolean is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      Found  : Boolean := False;
   begin
      Ada.Directories.Start_Search
        (Search, Directory, "*",
         [Ada.Directories.Directory => True, Ada.Directories.Ordinary_File => True, others => False]);
      while not Found and then Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
            Full : constant String := Ada.Directories.Full_Name (Item);
         begin
            if Ada.Directories.Kind (Item) = Ada.Directories.Directory then
               if Name /= "." and then Name /= ".." then
                  Found := Tree_Contains (Full, Pattern);
               end if;
            else
               Found := Text_Contains (Full, Pattern);
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      return Found;
   end Tree_Contains;

   function Source_Contains (Pattern : String) return Boolean is
      Sources : constant String := Path ("src");
   begin
      if not Project_Tools.Files.Directory_Exists (Sources) then
         raise Program_Error with "the repository has no src directory to inspect (looked for " & Sources & ")";
      end if;
      return Tree_Contains (Sources, Pattern);
   end Source_Contains;

end Files_Suite.Repository;
