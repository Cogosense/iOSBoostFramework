
#
# bjam source code is not c99 compatible, setting iOS9.3
# compatibility forces c99 mode, iOS9.3 is default level for
# Xcode 7.3.1
#
all : env
	unset IPHONEOS_DEPLOYMENT_TARGET ;\
	unset SDKROOT ;\
	./build.sh
	tar -cjf boost.framework.tar.bz2 boost.framework

env:
	env

clean :
	$(RM) -r ios boost_1_58_0 boost.framework
