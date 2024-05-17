###################################################
#   Microsoft PowerShell                          #
#   Terminal server permanent patch by Mavelot    #
#   ver 1.0                                       #
#   last modify: 15/04/2024                       #
###################################################


###############################################################
#                                                             #
#   Change following terminal service file target if needed   #
#                                                             #
###############################################################

$termsrv_file = "c:\windows\system32\termsrv.dll"

# Variable definition

$termsrv_file_patched = "$termsrv_file.patched"
$hash_file = (Get-FileHash "$termsrv_file" -a md5).Hash

# Check if dll was chaged since last run

If (Test-Path -path $termsrv_file_patched -PathType Leaf) {
	$hash_file_patched = (Get-FileHash "$termsrv_file_patched" -a md5).Hash
} else {
	$hash_file_patched = "none"
}
  
# If hash is different then do patching else end script

if ( $hash_file -ne $hash_file_patched) {

	    #   Get status of the two services UmRdpService and TermService

		$svc_UmRdpService_status = (get-service UmRdpService).status
		$svc_TermService_status  = (get-service TermService ).status

		#   print status

		write-host "Status of service UmRdpService: $svc_TermService_status"
		write-host "Status of service TermService:  $svc_TermService_status"

		#   stopping them
		
		write-host "Stopping services...."
		stop-service UmRdpService
		stop-service TermService
		
		#   Wait 5 seconds to ensure service stops
		Start-Sleep -s 5

		#   get status againd and print
		
		$svc_UmRdpService_status = (get-service UmRdpService).status
		$svc_TermService_status  = (get-service TermService ).status

		write-host "Status of service UmRdpService: $svc_TermService_status"
		write-host "Status of service TermService:  $svc_TermService_status"

		#   Save ACL and owner of termsrv_test.dll

		$termsrv_dll_acl   = get-acl $termsrv_file
		$termsrv_dll_owner = $termsrv_dll_acl.owner
		write-host "Owner of termsrv.dll:           $termsrv_dll_owner"

		#   Create backup of termsrv.dll

		copy-item  $termsrv_file "$termsrv_file.copy"

		#   Take ownership of the DLL...

		takeown /f $termsrv_file

		$new_termsrv_dll_owner = (get-acl $termsrv_file).owner

		# grant (/G) full control (:F) to myself
		
		write-host "Grant Full Access to dll..."
		icacls.exe  $termsrv_file /grant `"$new_termsrv_dll_owner`":F

		#
		#   Read DLL as byte-array in order to modify the bytes.
		#
		#   See https://stackoverflow.com/a/57342311/180275 for some details.
		#
		# $dll_as_bytes = get-content $termsrv_file -raw -asByteStream    # PowerShell Core version
		  $dll_as_bytes = get-content $termsrv_file -raw -encoding byte   # PowerShell traditional version

		#
		#   Convert the byte array to a string that represents each byte's value
		#   as hexadecimal value, separated by spaces:
		#
		$dll_as_text = $dll_as_bytes.forEach('ToString', 'X2') -join ' '

		#
		#   Search for byte array (which is dependent on the Windows edition) and replace them.
		#   See
		#      http://woshub.com/how-to-allow-multiple-rdp-sessions-in-windows-10/
		#   for details.
		#

		  #$dll_as_text_replaced = $dll_as_text -replace '39 81 3C 06 00 00 0F 84 A7 3A 01 00', 'B8 00 01 00 00 89 81 38 06 00 00 90' # Windows 22H2 - 10.0.19041.4239
		  $dll_as_text_replaced = $dll_as_text -replace '39 81 3C 06 00 00 0F 84 .. .. .. ..', 'B8 00 01 00 00 89 81 38 06 00 00 90'


		#
		#   Use the replaced string to create a byte array again
		#
		# [byte[]] $dll_as_bytes_replaced = -split $dll_as_text_replaced -replace '^', '0x' # PowerShell Core version
		  [byte[]] $dll_as_bytes_replaced = -split $dll_as_text_replaced -replace '^', '0x' # PoserShell traditional version

		#
		#   Create termsrv.dll.patched from byte array:
		#
		set-content $termsrv_file_patched -encoding byte -Value $dll_as_bytes_replaced

		#
		#   Compare patched and original DLL (/b: binary comparison)
		#
		fc.exe /b $termsrv_file_patched $termsrv_file
		#
		#   Expected output something like:
		#
		#       0001F215: B8 39
		#       0001F216: 00 81
		#       0001F217: 01 3C
		#       0001F218: 00 06
		#       0001F21A: 89 00
		#       0001F21B: 81 0F
		#       0001F21C: 38 84
		#       0001F21D: 06 5D
		#       0001F21E: 00 61
		#       0001F21F: 00 01
		#       0001F220: 90 00
		#

		#
		#   Overwrite original DLL with patched version:
		#
		copy-item $termsrv_file_patched $termsrv_file

		#
		#   Restore original ACL:
		#
		set-acl $termsrv_file $termsrv_dll_acl

		#
		#   Start services again:
		#
		# start-service UmRdpService
		# start-service TermService
		start-service TermService
		start-service UmRdpService

}	else {

	echo "DLL Already patched. Nothing to do"
}	
 




