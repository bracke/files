with Ada.Directories;

with Files.File_System;
with Files.Job_Context;
with Files.Job_Transports;
with Hostkit.Fs;

package body Files.Job_Cleanup is
   use type Files.Job_Transports.Claim_Outcome;

   function Run
     (Directory           : String;
      Expected_Identity   : String;
      Attempt_Limit       : Positive := 8;
      Initial_Retry_Delay : Duration := 0.25;
      Maximum_Retry_Delay : Duration := 4.0;
      Discard_Unreadable_On_Last_Attempt : Boolean := True)
      return Cleanup_Outcome
   is
      Stages      : constant String := Hostkit.Fs.Join (Directory, "stages");
      Retry_Delay : Duration := Duration'Max (0.0, Initial_Retry_Delay);
      Delay_Limit : constant Duration := Duration'Max (Retry_Delay, Maximum_Retry_Delay);
      Claim       : Files.Job_Transports.Lease;
      Have_Claim  : Boolean := False;

      function Directory_Gone return Boolean is
      begin
         return not Ada.Directories.Exists (Directory)
           and then not Hostkit.Fs.Is_Link (Directory);
      exception
         when others => return False;
      end Directory_Gone;
   begin
      for Attempt in 1 .. Attempt_Limit loop
         if not Have_Claim then
            declare
               Outcome : constant Files.Job_Transports.Claim_Outcome :=
                 Files.Job_Transports.Claim_Abandoned
                   (Directory, Expected_Identity, Claim);
            begin
               Have_Claim := Outcome = Files.Job_Transports.Claim_Acquired;
               if Outcome = Files.Job_Transports.Claim_Busy then
                  return Cleanup_Busy;
               elsif Outcome = Files.Job_Transports.Claim_Refused then
                  return (if Directory_Gone then Cleanup_Removed else Cleanup_Refused);
               elsif Outcome = Files.Job_Transports.Claim_Unrecoverable then
                  return Cleanup_Unrecoverable;
               end if;
            end;
         end if;

         --  A temporarily unreadable transport is retryable, but no contents
         --  are inspected and no pathname is removed until both its marker and
         --  the retained root identity validate.
         if Have_Claim and then not Files.Job_Transports.Holds (Claim, Directory) then
            --  The pathname or marker changed after acquisition. Drop the
            --  stale claim and classify the current entry on the next pass.
            Files.Job_Transports.Release (Claim);
            Have_Claim := False;
         end if;
         if Have_Claim and then Files.Job_Transports.Matches
           (Directory, Expected_Identity)
         then
            Files.Job_Context.Clean_Stages
              (Directory, Claim,
               Discard_Unreadable =>
                 Discard_Unreadable_On_Last_Attempt and then Attempt = Attempt_Limit);
            if not Ada.Directories.Exists (Stages) then
               begin
                  if not Files.Job_Transports.Retire (Claim, Directory) then
                     return Cleanup_Failed;
                  end if;
                  --  Windows refuses to remove a directory containing the open
                  --  lease handle. The identity-bound mutation remains the
                  --  authority boundary after this handle is closed. A durable
                  --  retiring marker keeps a late helper from joining then.
                  Files.Job_Transports.Release (Claim);
                  Have_Claim := False;
                  declare
                     Removed : constant Files.File_System.Mutation_Result :=
                       Files.File_System.Delete_Staging_Entry (Directory, Expected_Identity);
                  begin
                     if Removed.Success and then Directory_Gone then
                        return Cleanup_Removed;
                     end if;
                  end;
               exception
                  when others => null;
               end;
            end if;
         end if;
         exit when Directory_Gone or else Attempt = Attempt_Limit;
         delay Retry_Delay;
         Retry_Delay := Duration'Min (Delay_Limit, Retry_Delay * 2.0);
      end loop;
      return (if Directory_Gone then Cleanup_Removed else Cleanup_Failed);
   exception
      when others => return Cleanup_Failed;
   end Run;
end Files.Job_Cleanup;
