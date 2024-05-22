function(build_apk target manifest apk_out_ res_dir asset_dir)
	if (NOT ANDROID_STL)
		set(ANDROID_STL ${CMAKE_ANDROID_STL_TYPE})
	endif()

	add_custom_command(TARGET ${target} POST_BUILD
			   COMMAND ${CMAKE_COMMAND} -E rm -rf ${apk_out_}
			   COMMAND ${CMAKE_COMMAND} -E make_directory ${apk_out_}
			   WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

	if (ANDROID_STL AND ANDROID_STL STREQUAL "c++_shared")
		set(_stllib $ENV{PREFIX}/lib/lib${ANDROID_STL}.so) # For building on termux
		if (NOT (EXISTS ${_stllib}))
			if (NOT ANDROID_NDK)
				set(ANDROID_NDK $ENV{ANDROID_NDK})
			endif()
			set(abi_ ${ANDROID_ABI})
			if (${ANDROID_ABI} STREQUAL "arm64-v8a")
				set(abi_ "aarch64")
			endif()
			string(TOLOWER ${CMAKE_HOST_SYSTEM_NAME} host_name_)
			set(_stllib ${ANDROID_NDK}/toolchains/llvm/prebuilt/${host_name_}-x86_64/sysroot/usr/lib/${abi_}-linux-android/lib${ANDROID_STL}.so)
			if (NOT (EXISTS ${_stllib}))
				message(FATAL_ERROR "Cannot find ${_stllib}. Be sure to set the ANDROID_NDK environment variable")
			endif()
			add_custom_command(TARGET ${target} POST_BUILD
					   COMMAND ${CMAKE_COMMAND} -E copy_if_different ${_stllib} ${apk_out_}/lib/${ANDROID_ABI}/lib${ANDROID_STL}.so
					   WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
		endif()
	endif()

	if (NOT ANDROID_ABI)
		set(ANDROID_ABI ${CMAKE_ANDROID_ARCH_ABI})
	endif()

	set(_android_jar $ENV{PREFIX}/share/aapt/android.jar)
	if (NOT (EXISTS ${_android_jar}))
		if (NOT ANDROID_SDK_ROOT)
			set(ANDROID_SDK_ROOT $ENV{ANDROID_SDK_ROOT})
		endif()
		if (NOT ANDROID_PLATFORM)
			set(ANDROID_PLATFORM $ENV{ANDROID_PLATFORM})
		endif()
		set(_android_jar ${ANDROID_SDK_ROOT}/platforms/${ANDROID_PLATFORM}/android.jar)
		if (NOT (EXISTS ${_android_jar}))
			set(_android_jar ${ANDROID_SDK_ROOT}/platforms/android-${ANDROID_PLATFORM}/android.jar)
		endif()
		if (NOT (EXISTS ${_android_jar}))
			message(FATAL_ERROR "Cannot find android.jar (${_android_jar}). Be sure to set ANDROID_SDK and ANDROID_PLATFORM")
		endif()
	endif()

	set(package_args_)
	if (res_dir)
		set(package_args_ "${package_args_} -S ${res_dir}")
	endif()
	if (asset_dir)
		set(package_args_ "${package_args_} -A ${asset_dir}")
	endif()

	# NOTE: The necessary binaries called here are typically located in $ANDROID_SDK_ROOT/build-tools/<version>/
	# NOTE: It is assumed that the default debug keystore is located at ~/.android/debug.keystore
	set(aapt_ aapt)
	set(zipalign_ zipalign)
	set(apksigner_ apksigner )
	add_custom_command(TARGET ${target} POST_BUILD
			   COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${target}> ${apk_out_}/lib/${ANDROID_ABI}/$<TARGET_FILE_NAME:${target}>
			   COMMAND ${aapt_} package -f -M ${manifest} -I ${_android_jar} ${package_args_} -F ${apk_out_}/${target}-unaligned.apk ${apk_out_}
			   COMMAND ${zipalign_} -f 4 ${apk_out_}/${target}-unaligned.apk ${apk_out_}/${target}.apk
			   COMMAND ${apksigner_} sign --ks $ENV{HOME}/.android/debug.keystore --ks-pass pass:android ${apk_out_}/${target}.apk
			   WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
endfunction()
