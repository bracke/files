with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Quick_Look;
with Files.Types;

with Files.Operations.Support;

separate (Files.Operations)
package body Search is
   use type Files.Types.Item_Kind;

   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Query : constant String := Files.Model.Filter_Text (Model);
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Search_Names);
      end if;
      if Query = "" then
         return Disabled (Model, "error.filter.empty");
      end if;

      declare
         Search : constant Files.File_System.Recursive_Search_Result :=
           Files.File_System.Search_Recursive (Files.Model.Current_Path (Model), Query, Settings);
      begin
         if not Search.Success then
            Files.Model.Set_Error (Model, To_String (Search.Error_Key));
            return Make_Result
              (Operation_Failed, To_String (Search.Error_Key), Files.Model.Current_Path (Model));
         end if;

         Files.Model.Replace_Items (Model, Search.Items);
         Files.Model.Note_Search_Results (Model, Files.Types.Search_Names);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (Files.Model.Current_Path (Model)));
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end;
   end Run_Recursive_Search;

   --  Bounded content-search guards. Bytes read per file mirror the Quick Look
   --  text preview cap; the file and depth caps mirror Directory_Size so the walk
   --  cannot run away on huge or deeply nested trees.
   Content_Search_Max_Bytes   : constant := 64 * 1024;
   Content_Search_Max_Matches : constant := 1_000;
   Content_Search_Max_Files   : constant := 20_000;
   Content_Search_Max_Depth   : constant := 64;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean is
   begin
      if Query = "" or else Bytes'Length = 0 then
         return False;
      end if;

      --  Skip binary payloads: a decisive NUL or a heavy share of control bytes
      --  means the file is not text, so it can never be a content match.
      if Files.Quick_Look.Looks_Binary (Bytes) then
         return False;
      end if;

      return Ada.Strings.Fixed.Index
        (Files.Types.To_Lower (Bytes), Files.Types.To_Lower (Query)) > 0;
   end Content_Matches;

   function Run_Content_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Query : constant String := Files.Model.Filter_Text (Model);
      Root  : constant String := Files.Model.Current_Path (Model);
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Search_Contents);
      end if;
      if Query = "" then
         return Disabled (Model, "error.filter.empty");
      end if;

      declare
         Matches      : Files.File_System.Item_Vectors.Vector;
         Files_Scanned : Natural := 0;
         Read_Error : Unbounded_String;

         procedure Visit (Directory_Path : String; Depth : Natural) is
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Directory_Path, Settings);
         begin
            if Files.Job_Context.Cancelled then
               return;
            end if;
            if Depth > Content_Search_Max_Depth or else Files_Scanned >= Content_Search_Max_Files
              or else Natural (Matches.Length) >= Content_Search_Max_Matches
            then
               Read_Error := To_Unbounded_String ("error.search.failed");
               return;
            end if;
            if not Load.Success then
               Read_Error := To_Unbounded_String
                 (if Depth = 0 then "error.directory.load" else "error.search.failed");
               return;
            end if;

            for Item of Load.Items loop
               exit when Files.Job_Context.Cancelled;
               if Item.Kind = Files.Types.Regular_File_Item
                 or else Item.Kind = Files.Types.Executable_Item
               then
                  if Natural (Matches.Length) >= Content_Search_Max_Matches
                    or else Files_Scanned >= Content_Search_Max_Files
                  then
                     Read_Error := To_Unbounded_String ("error.search.failed");
                     return;
                  end if;
                  Files_Scanned := Files_Scanned + 1;
                  declare
                     Read_Ok : Boolean;
                     Bytes : constant String :=
                       Files.File_System.Read_Preview_Text
                         (To_String (Item.Full_Path), Content_Search_Max_Bytes + 1, Read_Ok);
                  begin
                     if not Read_Ok then
                        Read_Error := To_Unbounded_String ("error.search.failed");
                     elsif Bytes'Length > Content_Search_Max_Bytes
                       and then not Files.Quick_Look.Looks_Binary (Bytes)
                     then
                        Read_Error := To_Unbounded_String ("error.search.failed");
                     elsif Content_Matches (Bytes, Query) then
                        Matches.Append (Item);
                     end if;
                  end;
               end if;
            end loop;

            --  Descend only into real directories. Symlinked directories arrive
            --  as Symlink_Item, so this walk is inherently cycle-safe.
            for Item of Load.Items loop
               exit when Files.Job_Context.Cancelled;
               if Item.Kind = Files.Types.Directory_Item then
                  Visit (To_String (Item.Full_Path), Depth + 1);
               end if;
            end loop;
         exception
            when others =>
               Read_Error := To_Unbounded_String
                 (if Depth = 0 then "error.directory.load" else "error.search.failed");
         end Visit;
      begin
         if not Exists_Safely (Root) then
            Files.Model.Set_Error (Model, "error.directory.load");
            return Make_Result (Operation_Failed, "error.directory.load", Root);
         end if;

         Visit (Root, 0);
         if Length (Read_Error) > 0 then
            Files.Model.Set_Error (Model, To_String (Read_Error));
            return Make_Result (Operation_Failed, To_String (Read_Error), Root);
         end if;
         Files.Model.Replace_Items (Model, Matches);
         Files.Model.Note_Search_Results (Model, Files.Types.Search_Contents);
         Files.Model.Set_Directory_Signature
           (Model, Files.File_System.Directory_State (Root));
         if Matches.Is_Empty then
            Files.Model.Set_Error (Model, "search.no_matches");
         else
            Files.Model.Set_Error (Model, "");
         end if;
         return Make_Result (Operation_Success, Path => Root);
      end;
   exception
      when others =>
         Files.Model.Set_Error (Model, "error.search.failed");
         return Make_Result (Operation_Failed, "error.search.failed", Root);
   end Run_Content_Search;

end Search;
