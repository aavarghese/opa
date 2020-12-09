package kubernetes.admission                                                # line 1

#@rulesSchema=input:data.schemas.kubernetes.admission,input.request.object:data.schemas.kubernetes.pod
deny[msg] {                                                                 # line 2
  input.request.kind.kinds == "Pod"                                          # line 3
  #image := input.request.object.spec.containers[_].image                    # line 4
  image := input.request.object.image
  not startswith(image, "hooli.com/")                                       # line 5
  msg := sprintf("image '%v' comes from untrusted registry", [image])       # line 6
}
