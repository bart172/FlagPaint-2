#import "HBFPPackageTableViewCell.h"
#import <Cephei/HBOutputForShellCommand.h>
#import <Preferences/PSSpecifier.h>

@implementation HBFPPackageTableViewCell {
	BOOL _loadingPackageIcon;
}

+ (UITableViewCellStyle)cellStyle {
	return UITableViewCellStyleSubtitle;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];

	self.detailTextLabel.text = specifier.properties[@"subtitleText"];

	if (_loadingPackageIcon || self.imageView.image != self.blankIcon) {
		return;
	}

	void (^getIcon)(NSString *identifier, NSURL *url) = ^(NSString *identifier, NSURL *url) {
		NSData *data = [NSData dataWithContentsOfURL:url];

		if (!data) {
			HBLogWarn(@"failed to get package icon for %@", identifier);
			return;
		}

		UIImage *image = [[UIImage alloc] initWithData:data scale:2];

		if (!image) {
			HBLogWarn(@"failed to read package icon for %@", identifier);
			return;
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			specifier.properties[@"iconImage"] = image;
			self.icon = image;
		});
	};

	NSString *identifier = self.specifier.properties[@"packageIdentifier"];
	NSString *repo = self.specifier.properties[@"packageRepository"];

	NSParameterAssert(identifier);

	NSString *iconField = HBOutputForShellCommand([NSString stringWithFormat:@"/usr/bin/dpkg-query -f '${Icon}' -W '%@'", identifier]);

	if (iconField && ![iconField isEqualToString:@""]) {
		NSURL *iconURL = [NSURL URLWithString:iconField];

		if (!iconURL.isFileURL) {
			HBLogWarn(@"icon url %@ for %@ isn't a file:// url", iconField, identifier);
			return;
		}

		getIcon(identifier, iconURL);
		return;
	}

	if (!repo) {
		_loadingPackageIcon = YES;

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			getIcon(identifier, [[[NSURL URLWithString:@"https://cydia.saurik.com/icon/"] URLByAppendingPathComponent:identifier] URLByAppendingPathExtension:@"png"]);

			_loadingPackageIcon = NO;
		});
	}
}

@end
