with Files.Quick_Look;
separate (Files.File_System)
function Search_Contents
  (Root_Path : String;
   Query     : String;
   Settings  : Files.Settings.Settings_Model)
   return Recursive_Search_Result
is
   Max_Bytes   : constant := 64 * 1024;
   Max_Matches : constant := 1_000;
   Max_Files   : constant := 20_000;
   Options     : constant Files.Types.Listing_Options := Files.Settings.Listing_Options_Of (Settings);
   Result : Recursive_Search_Result :=
     (Success   => False,
      Root_Path => To_Unbounded_String (Root_Path),
      Query     => To_Unbounded_String (Query),
      Items     => Item_Vectors.Empty_Vector,
      Error_Key => Null_Unbounded_String);
   Files_Read : Natural := 0;

   --  Only what is read or descended into is built into an item.
   function Include (Name : String; Kind : Files.Types.Item_Kind) return Boolean is
      pragma Unreferenced (Name);
   begin
      return Kind in Files.Types.Directory_Item | Files.Types.Regular_File_Item | Files.Types.Executable_Item;
   end Include;

   procedure Visit (Directory_Path : String; Depth : Natural) is
   begin
      --  Checked before the folder is listed: once a limit is hit or a read
      --  failed, the search has failed, and listing every remaining sibling
      --  in full only to return was most of its cost.
      if Files.Job_Context.Cancelled or else Length (Result.Error_Key) > 0 then
         return;
      end if;
      if Depth > Max_Search_Depth or else Files_Read >= Max_Files
        or else Natural (Result.Items.Length) >= Max_Matches
      then
         Result.Error_Key := To_Unbounded_String ("error.search.failed");
         return;
      end if;
      declare
         Load : constant Directory_Load_Result :=
           Load_Directory_Filtered (Directory_Path, Settings, Options, Include'Access);
      begin
         if not Load.Success then
            Result.Error_Key := To_Unbounded_String
              (if Depth = 0 then "error.directory.load" else "error.search.failed");
            return;
         end if;
         for Item of Load.Items loop
            exit when Files.Job_Context.Cancelled;
            if Item.Kind in Files.Types.Regular_File_Item | Files.Types.Executable_Item then
               if Natural (Result.Items.Length) >= Max_Matches or else Files_Read >= Max_Files then
                  Result.Error_Key := To_Unbounded_String ("error.search.failed");
                  return;
               end if;
               Files_Read := Files_Read + 1;
               declare
                  Read_Ok : Boolean;
                  Bytes   : constant String := Read_Preview_Text (To_String (Item.Full_Path), Max_Bytes + 1, Read_Ok);
               begin
                  if not Read_Ok then
                     Result.Error_Key := To_Unbounded_String ("error.search.failed");
                  elsif Content_Matches
                    (Bytes (Bytes'First .. Bytes'First - 1 + Natural'Min (Bytes'Length, Max_Bytes)), Query)
                  then
                     Result.Items.Append (Item);
                  elsif Bytes'Length > Max_Bytes and then not Files.Quick_Look.Looks_Binary (Bytes) then
                     --  A text file longer than is read and no match in what
                     --  was: its match could lie past it.
                     Result.Error_Key := To_Unbounded_String ("error.search.failed");
                  end if;
               end;
            end if;
         end loop;
         --  Real folders only: a linked folder arrives as a link item.
         for Item of Load.Items loop
            exit when Files.Job_Context.Cancelled or else Length (Result.Error_Key) > 0;
            if Item.Kind = Files.Types.Directory_Item then
               Visit (To_String (Item.Full_Path), Depth + 1);
            end if;
         end loop;
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         Result.Error_Key := To_Unbounded_String
           (if Depth = 0 then "error.directory.load" else "error.search.failed");
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
      Result.Error_Key := To_Unbounded_String ("error.search.failed");
      return Result;
end Search_Contents;
