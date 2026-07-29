with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Strings.Fixed;
with Files.Fs;

separate (Files.File_System)
package body Search is

   use type Files.Types.Item_Kind;
   function Search_Recursive
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := 1_000)
      return Recursive_Search_Result
   is
      Result : Recursive_Search_Result :=
        (Success   => False,
         Root_Path => To_Unbounded_String (Root_Path),
         Query     => To_Unbounded_String (Query),
         Items     => Item_Vectors.Empty_Vector,
         Error_Key => Null_Unbounded_String);
      Normalized_Query : constant String := Files.Types.To_Lower (Query);

      --  Bound the walk independently of how many entries match. The only stop
      --  condition used to be Max_Items, which advances solely on a match, so a
      --  query that matched little or nothing walked the entire subtree on the UI
      --  thread (a freeze). Mirror the content search's depth + total-scanned caps
      --  (files-operations.adb). The name match is far cheaper per entry than a
      --  content read, so the scanned cap is correspondingly larger.
      Max_Search_Depth    : constant := 64;
      Max_Entries_Scanned : constant := 100_000;
      Scanned             : Natural := 0;

      function Matches (Name : UString) return Boolean is
      begin
         return Normalized_Query = ""
           or else Ada.Strings.Fixed.Index
             (Files.Types.To_Lower (To_String (Name)), Normalized_Query) > 0;
      end Matches;

      procedure Visit (Directory_Path : String; Depth : Natural) is
         Load : constant Directory_Load_Result := Load_Directory (Directory_Path, Settings);
      begin
         if not Load.Success
           or else Depth > Max_Search_Depth
           or else Natural (Result.Items.Length) >= Max_Items
           or else Scanned >= Max_Entries_Scanned
         then
            return;
         end if;

         for Item of Load.Items loop
            exit when Natural (Result.Items.Length) >= Max_Items
              or else Scanned >= Max_Entries_Scanned;
            Scanned := Scanned + 1;
            if Matches (Item.Name) then
               Result.Items.Append (Item);
            end if;
         end loop;

         --  Descend only into real directories. Symlinked directories arrive as
         --  Symlink_Item, so this walk is inherently cycle-safe.
         for Item of Load.Items loop
            exit when Natural (Result.Items.Length) >= Max_Items
              or else Scanned >= Max_Entries_Scanned;
            if Item.Kind = Files.Types.Directory_Item then
               Visit (To_String (Item.Full_Path), Depth + 1);
            end if;
         end loop;
      exception
         when others =>
            null;
      end Visit;
   begin
      if not Files.Fs.Directory_Exists (Root_Path)
      then
         Result.Error_Key := To_Unbounded_String ("error.directory.load");
         return Result;
      end if;

      Result.Root_Path := To_Unbounded_String (Ada.Directories.Full_Name (Root_Path));
      Visit (Root_Path, 0);
      Result.Success := True;
      return Result;
   exception
      when others =>
         Result.Success := False;
         Result.Error_Key := To_Unbounded_String ("error.search.failed");
         return Result;
   end Search_Recursive;

end Search;
