separate (Files.Refresh)
   procedure Run_Helper (Directory : String) is
      use type Files.UI_Types.Search_Scope;
      Work : Request;
      Done : Outcome;

      procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         Write_Outcome (Stream, Done);
      end Write;
   begin
      Work := Read_Request (Hostkit.Fs.Join (Directory, Files.Jobs.Process.Request_File));
      if Work.Searched /= Files.UI_Types.Filter_Here then
         --  The window shows search results: they are found again, by the
         --  one search a view's results come from.
         declare
            Found : constant Files.File_System.Search.Folder_Search_Result :=
              Files.File_System.Search.Search_Folder
                (To_String (Work.Root), To_String (Work.Query), Work.Searched,
                 Files.Settings.Classification_Of (Work.Settings),
                 Files.Settings.Listing_Options_Of (Work.Settings));
         begin
            Done.Success := Found.Success;
            Done.Reloaded := Found.Success;
            Done.Error_Key := Found.Error_Key;
            if Found.Success then
               Done.Items := Found.Items;
               Done.Notice := Found.Notice;
               Done.Signature := Found.Signature;
            else
               Done.Signature := Work.Previous;
            end if;
         end;
      elsif Work.Recent then
         Done.Items := Load_Recent_Items (Work.Settings);
         Done.Signature := Work.Previous;
         Done.Success := True;
         Done.Reloaded := True;
      else
         declare
            Change : constant Files.File_System.Directory_Change_Result :=
              Files.File_System.Detect_Directory_Change (Work.Previous, To_String (Work.Root));
         begin
            Done.Signature := Change.After_State;
            Done.Error_Key := Change.Error_Key;
            if Length (Change.Error_Key) = 0 then
               Done.Success := True;
               if Work.Force or else Change.Changed then
                  declare
                     Loaded : constant Files.File_System.Directory_Load_Result :=
                       Files.File_System.Load_Directory_Generating_Thumbnails
                         (To_String (Work.Root), Files.Settings.Classification_Of (Work.Settings),
                          Files.Settings.Listing_Options_Of (Work.Settings));
                  begin
                     Done.Success := Loaded.Success;
                     Done.Reloaded := Loaded.Success;
                     Done.Items := Loaded.Items;
                     Files.Job_Payloads.Fit_Thumbnails (Done.Items);
                     Done.Error_Key := Loaded.Error_Key;
                     --  Use the signature from before loading, so a concurrent
                     --  change during enumeration schedules another refresh.
                  end;
               end if;
            end if;
         end;
      end if;
      Files.Jobs.Records.Publish_Result (Directory, Write'Access);
   end Run_Helper;
