separate (Files.File_System)
function Search_Tree
  (Root_Path : String;
   Settings  : Files.Settings.Settings_Model;
   Wanted    : not null access function (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
   Judge     : not null access function (Item : Directory_Item) return Search_Verdict;
   Max_Items : Natural)
   return Recursive_Search_Result
is
   Options : constant Files.Types.Listing_Options := Files.Settings.Listing_Options_Of (Settings);
   Result  : Recursive_Search_Result;

   --  Bound the walk independently of how many entries match: a query that
   --  matched little or nothing once walked the entire subtree. Every listed
   --  entry counts, built into an item or not.
   Max_Entries_Scanned : constant := 100_000;
   Scanned             : Natural := 0;
   --  A limit was reached: nothing more is listed or judged.
   Stopped             : Boolean := False;

   procedure Stop is
   begin
      Result.Truncated := True;
      Stopped := True;
   end Stop;

   function Include (Name : String; Kind : Files.Types.Item_Kind) return Boolean is
   begin
      Scanned := Scanned + 1;
      return Kind = Files.Types.Directory_Item or else Wanted (Name, Kind);
   end Include;

   procedure Visit (Directory_Path : String; Depth : Natural) is
   begin
      if Files.Job_Context.Cancelled or else Stopped then
         return;
      end if;
      --  Too deep: this folder goes unsearched, its siblings do not.
      if Depth > Max_Search_Depth then
         Result.Truncated := True;
         return;
      end if;
      --  Checked before the folder is listed: listing it in full only to
      --  return was most of a stopped search's cost.
      if Natural (Result.Items.Length) >= Max_Items or else Scanned >= Max_Entries_Scanned then
         Stop;
         return;
      end if;
      declare
         Load : constant Directory_Load_Result :=
           Load_Directory_Filtered (Directory_Path, Settings, Options, Include'Access);
      begin
         if not Load.Success then
            if Depth = 0 then
               Result.Error_Key := To_Unbounded_String ("error.directory.load");
               Stopped := True;
            else
               Result.Incomplete := True;
            end if;
            return;
         end if;
         for Item of Load.Items loop
            exit when Files.Job_Context.Cancelled;
            --  Reaching the cap on the final item of a complete walk is
            --  allowed; an item left unjudged past it is not.
            if Natural (Result.Items.Length) >= Max_Items then
               Stop;
               return;
            end if;
            case Judge (Item) is
               when Found =>
                  Result.Items.Append (Item);
               when Passed =>
                  null;
               when Undecided =>
                  Result.Incomplete := True;
               when Exhausted =>
                  Stop;
                  return;
            end case;
         end loop;
         --  Real folders only: a linked folder arrives as a link item.
         for Item of Load.Items loop
            exit when Files.Job_Context.Cancelled or else Stopped;
            if Item.Kind = Files.Types.Directory_Item then
               Visit (To_String (Item.Full_Path), Depth + 1);
            end if;
         end loop;
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         if Depth = 0 then
            Result.Error_Key := To_Unbounded_String ("error.directory.load");
            Stopped := True;
         else
            Result.Incomplete := True;
         end if;
   end Visit;
begin
   if not Files.Fs_Primitives.Directory_Exists (Root_Path) then
      Result.Error_Key := To_Unbounded_String ("error.directory.load");
      return Result;
   end if;
   Visit (Root_Path, 0);
   Result.Success := Length (Result.Error_Key) = 0;
   return Result;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Result.Success := False;
      Result.Error_Key := To_Unbounded_String ("error.search.failed");
      return Result;
end Search_Tree;
