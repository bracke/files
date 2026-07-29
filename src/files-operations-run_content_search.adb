separate (Files.Operations)
   function Run_Content_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Query : constant String := Files.Model.Filter_Text (Model);
      Root  : constant String := Files.Model.Current_Path (Model);
   begin
      if Query = "" then
         return Disabled (Model, "error.filter.empty");
      end if;

      declare
         Matches      : Files.File_System.Item_Vectors.Vector;
         Files_Scanned : Natural := 0;

         procedure Visit (Directory_Path : String; Depth : Natural) is
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Directory_Path, Settings);
         begin
            if not Load.Success or else Depth > Content_Search_Max_Depth then
               return;
            end if;

            for Item of Load.Items loop
               exit when Natural (Matches.Length) >= Content_Search_Max_Matches
                 or else Files_Scanned >= Content_Search_Max_Files;
               if Item.Kind = Files.Types.Regular_File_Item
                 or else Item.Kind = Files.Types.Executable_Item
               then
                  Files_Scanned := Files_Scanned + 1;
                  declare
                     Bytes : constant String :=
                       Files.File_System.Read_Preview_Text
                         (To_String (Item.Full_Path), Content_Search_Max_Bytes);
                  begin
                     if Content_Matches (Bytes, Query) then
                        Matches.Append (Item);
                     end if;
                  end;
               end if;
            end loop;

            --  Descend only into real directories. Symlinked directories arrive
            --  as Symlink_Item, so this walk is inherently cycle-safe.
            for Item of Load.Items loop
               exit when Natural (Matches.Length) >= Content_Search_Max_Matches
                 or else Files_Scanned >= Content_Search_Max_Files;
               if Item.Kind = Files.Types.Directory_Item then
                  Visit (To_String (Item.Full_Path), Depth + 1);
               end if;
            end loop;
         exception
            when others =>
               null;
         end Visit;
      begin
         if not Exists_Safely (Root) then
            Files.Model.Set_Error (Model, "error.directory.load");
            return Make_Result (Operation_Failed, "error.directory.load", Root);
         end if;

         Visit (Root, 0);
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
