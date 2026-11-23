separate (Files.Refresh)
   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Force : Boolean := False;
      Select_Name : String := "";
      Select_Path : String := "";
      Search_Again : Boolean := False) return Files.Operation_Results.Operation_Result
   is
      use type Files.UI_Types.Search_Scope;
      Job : Files.Jobs.Process.Session;
      Searching : constant Boolean :=
        Search_Again and then Force and then Files.Model.Filtering.Search_Results_Are_Active (Model)
        and then Files.Model.Filtering.Search_Scope_Of (Model) /= Files.UI_Types.Filter_Here;
      --  A search's notice is about the results shown, not an operation's
      --  diagnostic: the read replaces it (with its own, when it searches).
      Previous_Error : constant String :=
        (if Files.File_System.Search.Is_Notice (Files.Model.Last_Error_Key (Model)) then ""
         else Files.Model.Last_Error_Key (Model));
      Work : constant Request :=
        (Root => To_Unbounded_String (Files.Model.Current_Path (Model)),
         Context_Revision => Files.Model.Listing_Revision (Model), Settings => Settings,
         Previous => Files.Model.Directory_Signature_Of (Model),
         --  A failed listing must be retried even when the directory signature
         --  is unchanged. Preserve operation errors, which a reload cannot fix.
         Recent => Files.Model.Recent.In_Recent_View (Model),
         Force => Force or else Previous_Error = Files.IO.Errors.Directory_Load_Key,
         --  An empty value means preserve the selection that is current when
         --  the read completes. A nonempty operation-requested name wins.
         Selection => To_Unbounded_String (Select_Name),
         Error_Key => (if Previous_Error = Files.IO.Errors.Directory_Load_Key then Null_Unbounded_String
                       else To_Unbounded_String (Previous_Error)),
         Select_Path => To_Unbounded_String (Select_Path),
         Searched =>
           (if Searching then Files.Model.Filtering.Search_Scope_Of (Model) else Files.UI_Types.Filter_Here),
         Query => (if Searching then To_Unbounded_String (Files.Model.Filtering.Filter_Text (Model))
                   else Null_Unbounded_String));
   begin
      if not Force and then (Work.Recent or else Files.Model.Filtering.Search_Results_Are_Active (Model)) then
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      elsif Files.Model.Jobs.Foreground_Job_Is_Active (Model) then
         --  The modal job's own result may not cover this read (a show-hidden
         --  change shared from another window while it ran): the reload is
         --  owed, and Resume_Owed starts it once the job is done.
         Files.Model.Note_Owed_Refresh (Model, Force => Force, Select_Name => Select_Name);
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      elsif not Force
        and then (Files.Model.Rename.Is_Active (Model) or else Files.Model.Creation.Temporary_Item_Is_Active (Model)
                  or else Files.Model.Command_Palette.Is_Open (Model))
      then
         --  Replacing the items now would drop the edit or close the palette:
         --  the reload is owed, and Resume_Owed starts it once they are done.
         Files.Model.Note_Owed_Refresh (Model, Force => False, Select_Name => Select_Name);
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      end if;
      if not Force and then Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)) then
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      end if;
      Cancel (Model);
      Files.Jobs.Process.Reserve (Job);
      declare
         procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
         begin
            Write_Request (Stream, Work);
         end Write;
      begin
         Files.Jobs.Process.Launch_With_Request (Job, Files.Jobs.Helper_Modes.Refresh, Write'Access);
      end;
      Files.Model.Jobs.Set_Background_Refresh (Model, Job);
      --  This read covers the current view, so any reload owed to it is paid.
      Files.Model.Clear_Owed_Refresh (Model);
      return (Status => Files.Operation_Results.Operation_Success, Path => Work.Root, others => <>);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Refresh");
         if Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, Files.IO.Errors.Directory_Load_Key);
         end if;
         return (Status => Files.Operation_Results.Operation_Failed,
                 Error_Key => To_Unbounded_String (Files.Model.Last_Error_Key (Model)), others => <>);
   end Start;
