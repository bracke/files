separate (Files.Refresh)
   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Boolean
   is
      use type Files.UI_Types.Search_Scope;
      Job : constant Files.Jobs.Process.Session := Files.Model.Jobs.Background_Refresh (Model);
      Work : Request;
      Done : Outcome;
      Finished, Cancelled : Boolean;
      Matching : Boolean := False;
      Requested : Request_Identity;

   begin
      if not Files.Jobs.Process.Active (Job) then
         return False;
      end if;
      --  Read only the request header from local transport. A navigation or edit
      --  must discard even a helper still blocked on the previous directory.
      Requested := Read_Request_Identity (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
      if Requested.Root /= Files.Model.Current_Path (Model) then
         Cancel (Model);
         return False;
      elsif Files.Model.Jobs.Foreground_Job_Is_Active (Model) then
         --  As in Start: the modal job's own result may not cover this read
         --  (a show-hidden change shared from another window), so the read
         --  is owed and Resume_Owed starts it again once the job is done.
         Owe_Reload (Model, Job);
         Cancel (Model);
         return False;
      elsif Requested.Context_Revision /= Files.Model.Listing_Revision (Model) then
         Owe_Reload (Model, Job);
         Cancel (Model);
         return False;
      elsif Files.Model.Command_Palette.Is_Open (Model)
        or else Files.Model.Rename.Is_Active (Model)
        or else Files.Model.Creation.Temporary_Item_Is_Active (Model)
      then
         --  Replacing the items would close the palette or drop the edit the
         --  user opened while this read ran: keep the result until they finish.
         return False;
      end if;
      Files.Jobs.Process.Poll (Job, Finished, Cancelled);
      if not Finished then
         return False;
      end if;
      Cancel (Model); --  Job keeps the finished transport alive through result collection.
      Work := Read_Request (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
      Matching := Work.Root = Files.Model.Current_Path (Model)
        and then Work.Recent = Files.Model.Recent.In_Recent_View (Model)
        and then Work.Context_Revision = Files.Model.Listing_Revision (Model)
        and then Files.Settings.Same_Listing (Work.Settings, Settings, Work.Recent)
        --  A search answers its query in its scope, while the window
        --  still shows those results.
        and then
          (Work.Searched = Files.UI_Types.Filter_Here
           or else (Files.Model.Filtering.Search_Results_Are_Active (Model)
                    and then Files.Model.Filtering.Search_Scope_Of (Model) = Work.Searched
                    and then Files.Model.Filtering.Filter_Text (Model) = To_String (Work.Query)));
      if not Matching and then not Cancelled
        and then Work.Root = Files.Model.Current_Path (Model)
      then
         Owe_Reload (Model, Job);
      end if;
      if not Matching or else Cancelled then
         return False;
      end if;
      Done := Read_Outcome (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Result_File));
      if not Done.Success then
         if Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, To_String (Done.Error_Key));
         end if;
         return False;
      end if;
      if Done.Reloaded then
         Reinstall_Listing
           (Model, Done.Items, Done.Signature,
            Recent        => Work.Recent,
            Searched      => Work.Searched,
            Select_Path   => To_String (Work.Select_Path),
            Select_Name   => To_String (Work.Selection),
            Fresh_Details => Work.Force);
      else
         Files.Model.Set_Directory_Signature (Model, Done.Signature);
      end if;
      declare
         --  The error kept from before the read, else a search's notice.
         Wanted : constant String :=
           (if Length (Work.Error_Key) = 0 and then Work.Searched /= Files.UI_Types.Filter_Here
            then To_String (Done.Notice)
            else To_String (Work.Error_Key));
      begin
         if Files.Model.Last_Error_Key (Model) /= Wanted then
            Files.Model.Set_Error (Model, Wanted);
         end if;
      end;
      Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
      return Done.Reloaded;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Refresh");
         Cancel (Model);
         if Matching and then Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, Files.IO.Errors.Directory_Load_Key);
         end if;
         return False;
   end Advance;
