with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Strings.Fixed;
with Files.Fs;
with Files.Job_Context;

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

      --  Every listed entry counts toward the scan cap; only names that match
      --  and folders to descend into are built into full items.
      function Include (Name : String; Kind : Files.Types.Item_Kind) return Boolean is
         use type Files.Types.Item_Kind;
      begin
         Scanned := Scanned + 1;
         return Kind = Files.Types.Directory_Item
           or else Matches (To_Unbounded_String (Name));
      end Include;

      procedure Visit (Directory_Path : String; Depth : Natural) is
      begin
         if Files.Job_Context.Cancelled then
            return;
         end if;
         if Depth > Max_Search_Depth or else Natural (Result.Items.Length) >= Max_Items
           or else Scanned >= Max_Entries_Scanned
         then
            Result.Error_Key := To_Unbounded_String ("error.search.failed");
            return;
         end if;
         declare
            Load : constant Directory_Load_Result :=
              Directory.Load_Directory_Filtered (Directory_Path, Settings, Include'Access);
         begin
            if not Load.Success then
               Result.Error_Key := To_Unbounded_String
                 (if Depth = 0 then "error.directory.load" else "error.search.failed");
               return;
            end if;
            for Item of Load.Items loop
               exit when Files.Job_Context.Cancelled;
               if Natural (Result.Items.Length) >= Max_Items or else Scanned > Max_Entries_Scanned then
                  Result.Error_Key := To_Unbounded_String ("error.search.failed");
                  return;
               end if;
               if Matches (Item.Name) then
                  Result.Items.Append (Item);
               end if;
            end loop;
            --  Only a skipped subtree makes the walk incomplete. Reaching a
            --  limit on the final file of a complete leaf listing is allowed.
            for Item of Load.Items loop
               exit when Files.Job_Context.Cancelled;
               if Item.Kind = Files.Types.Directory_Item then
                  Visit (To_String (Item.Full_Path), Depth + 1);
               end if;
            end loop;
         end;
      exception
         when others =>
            Result.Error_Key := To_Unbounded_String
              (if Depth = 0 then "error.directory.load" else "error.search.failed");
      end Visit;
   begin
      if not Files.Fs.Directory_Exists (Root_Path)
      then
         Result.Error_Key := To_Unbounded_String ("error.directory.load");
         return Result;
      end if;

      Result.Root_Path := To_Unbounded_String (Ada.Directories.Full_Name (Root_Path));
      Visit (Root_Path, 0);
      Result.Success := Length (Result.Error_Key) = 0;
      return Result;
   exception
      when others =>
         Result.Success := False;
         Result.Error_Key := To_Unbounded_String ("error.search.failed");
         return Result;
   end Search_Recursive;

end Search;
